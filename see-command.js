/**
 * OpenVist - Discord bot "/see" command  (v1.1.0)
 *
 * Integration example for Discord.js bots.
 * Add this file to your bot's commands directory and register it.
 *
 * Configuration via environment variables:
 *   OPENCODE_SEE_PATH  Path to the opencode-see script
 *                      (default: $HOME/.local/bin/opencode-see)
 *   OPENCODE_SS_PATH   File that stores the latest screenshot path
 *                      (default: $XDG_RUNTIME_DIR/opencode-latest-ss-path
 *                       or /tmp/opencode-latest-ss-path)
 *   OPENVIST_COOLDOWN  Cooldown per user in milliseconds (default: 10000)
 */

import { SlashCommandBuilder } from 'discord.js';
import { execSync } from 'node:child_process';
import { existsSync, readFileSync, unlinkSync } from 'node:fs';
import { homedir } from 'node:os';

const SEE_SCRIPT = process.env.OPENCODE_SEE_PATH
  || `${homedir()}/.local/bin/opencode-see`;
const SS_PATH_FILE = process.env.OPENCODE_SS_PATH
  || `${process.env.XDG_RUNTIME_DIR || '/tmp'}/opencode-latest-ss-path`;

// Per-user cooldown tracking (rate limiting).
const COOLDOWN_MS = parseInt(process.env.OPENVIST_COOLDOWN || '10000', 10);
const cooldowns = new Map();

/**
 * Check whether a user is on cooldown. Returns the remaining milliseconds,
 * or 0 if the user may proceed (and records the timestamp).
 */
function checkCooldown(userId) {
  const now = Date.now();
  const last = cooldowns.get(userId) || 0;
  const remaining = last + COOLDOWN_MS - now;
  if (remaining > 0) {
    return remaining;
  }
  cooldowns.set(userId, now);
  return 0;
}

// Available prompt templates (kept in sync with the prompts/ directory).
const PROMPT_TEMPLATES = [
  { name: 'Default', value: 'default' },
  { name: 'Errors / warnings', value: 'errors' },
  { name: 'Code editor / terminal', value: 'code' },
  { name: 'Debugging session', value: 'debug' },
  { name: 'UI layout', value: 'ui' },
];

/**
 * Turn a raw opencode-see failure into a short, actionable Discord message.
 */
function friendlyError(error) {
  const raw = (error.stderr?.toString().trim() || error.message || 'Unknown error')
    .replace(/^.*error:\s*/i, '');
  if (/not found in Ollama/i.test(raw)) {
    const m = raw.match(/Model '([^']+)'/);
    const model = m ? m[1] : 'the model';
    return `Model '${model}' is not installed. Run \`ollama pull ${model}\` on the host.`;
  }
  if (/cannot reach Ollama|ollama serve/i.test(raw)) {
    return "Can't reach Ollama. Is `ollama serve` running on the host?";
  }
  if (/timed out/i.test(raw)) {
    return 'The vision model timed out. Try a smaller model or increase the timeout.';
  }
  if (/LEFT_MON|RIGHT_MON/i.test(raw)) {
    return 'A monitor environment variable is not set on the host. Run `opencode-see --check`.';
  }
  if (/grim failed|region selection cancelled/i.test(raw)) {
    return 'Screenshot capture failed. Make sure the host is running Wayland/Hyprland.';
  }
  if (/killed|timeout/i.test(error.message || '')) {
    return 'The command took too long and was killed.';
  }
  return raw.length > 1800 ? raw.slice(0, 1800) + '...' : raw;
}

// Subcommands for the /see slash command.
const subcommands = [
  {
    name: 'capture',
    description: 'Take a screenshot and describe what is on screen',
    options: [
      {
        name: 'mode', description: 'Capture mode', required: false,
        choices: ['full', 'left', 'right', 'region', 'window'],
      },
      { name: 'prompt', description: 'Custom prompt for the vision model', required: false },
      {
        name: 'template', description: 'Prompt template to use', required: false,
        choices: PROMPT_TEMPLATES.map(t => ({ name: t.name, value: t.value })),
      },
      { name: 'json', description: 'Send the result as a JSON code block', required: false, type: 'boolean' },
      { name: 'ephemeral', description: 'Only show the result to you', required: false, type: 'boolean' },
      { name: 'annotate', description: 'Overlay the description on the screenshot', required: false, type: 'boolean' },
    ],
  },
  {
    name: 'history',
    description: 'Show recent analyses from history',
    options: [
      { name: 'count', description: 'Number of entries to show (default 5)', required: false, type: 'integer' },
    ],
  },
];

// Build the SlashCommandBuilder from the subcommand definitions.
const builder = new SlashCommandBuilder()
  .setName('see')
  .setDescription('Take a screenshot and describe what is on screen');

for (const sub of subcommands) {
  const s = builder.addSubcommand(b => b.setName(sub.name).setDescription(sub.description));
  for (const opt of sub.options) {
    const type = opt.type === 'integer' ? 'addIntegerOption' : opt.type === 'boolean' ? 'addBooleanOption' : 'addStringOption';
    s[type](o => {
      o.setName(opt.name).setDescription(opt.description).setRequired(opt.required ?? false);
      if (opt.choices) {
        o.addChoices(...opt.choices.map(c =>
          typeof c === 'string' ? { name: c, value: c } : c));
      }
      return o;
    });
  }
}

/**
 * Run opencode-see and return { output, capPath }.
 */
function runSee(args) {
  const cmd = `${JSON.stringify(SEE_SCRIPT)} ${args.join(' ')}`;
  const output = execSync(cmd, {
    timeout: 120000, encoding: 'utf8', maxBuffer: 10 * 1024 * 1024,
    stdio: ['ignore', 'pipe', 'pipe'],
  });

  let capPath = null;
  if (existsSync(SS_PATH_FILE)) {
    capPath = readFileSync(SS_PATH_FILE, 'utf8').trim();
    try { unlinkSync(SS_PATH_FILE); } catch {}
  }
  return { output, capPath };
}

export const see = {
  data: builder,

  async execute(interaction) {
    // --- rate limiting ---------------------------------------------------
    const remaining = checkCooldown(interaction.user.id);
    if (remaining > 0) {
      const secs = Math.ceil(remaining / 1000);
      await interaction.reply({
        content: `You're on cooldown. Try again in ${secs}s.`,
        ephemeral: true,
      });
      return;
    }

    const sub = interaction.options.getSubcommand();

    // --- /see history ----------------------------------------------------
    if (sub === 'history') {
      const count = interaction.options.getInteger('count') || 5;
      await interaction.deferReply({ ephemeral: true });
      try {
        const { output } = runSee(['--history', String(count)]);
        const text = output.trim() || 'History is empty.';
        const body = text.length > 1900 ? text.slice(0, 1900) + '...' : text;
        await interaction.editReply({ content: `\`\`\`\n${body}\n\`\`\`` });
      } catch (error) {
        await interaction.editReply({ content: `Failed: ${friendlyError(error)}` });
      }
      return;
    }

    // --- /see capture ----------------------------------------------------
    const mode = interaction.options.getString('mode') || 'full';
    const customPrompt = interaction.options.getString('prompt');
    const template = interaction.options.getString('template');
    const asJson = interaction.options.getBoolean('json') || false;
    const ephemeral = interaction.options.getBoolean('ephemeral') || false;
    const annotate = interaction.options.getBoolean('annotate') || false;

    await interaction.deferReply({ ephemeral });

    const args = [];
    if (template) args.push('--prompt-template', JSON.stringify(template));
    if (annotate) args.push('--annotate');
    if (asJson) args.push('--json');
    args.push(JSON.stringify(mode));
    if (customPrompt) args.push(JSON.stringify(customPrompt));

    try {
      const { output, capPath } = runSee(args);

      if (asJson) {
        // Send the JSON result as a code block.
        let jsonText = output.trim();
        try {
          // Pretty-print for readability.
          jsonText = JSON.stringify(JSON.parse(jsonText), null, 2);
        } catch {}
        const body = jsonText.length > 1900 ? jsonText.slice(0, 1900) + '\n...' : jsonText;
        const payload = { content: `\`\`\`json\n${body}\n\`\`\`` };
        if (capPath && existsSync(capPath)) payload.files = [capPath];
        await interaction.editReply(payload);
        return;
      }

      const lines = output.trim().split('\n');
      const markerIdx = lines.findIndex(l => l.startsWith('Screen capture:')
        || l.startsWith('Annotated screenshot:'));
      const description = lines
        .filter((_, i) => markerIdx === -1 || i !== markerIdx)
        .join('\n')
        .trim();

      const truncated = description.length > 1900
        ? description.slice(0, 1900) + '...'
        : description;

      const payload = { content: truncated || 'Screenshot taken.' };
      if (capPath && existsSync(capPath)) {
        payload.files = [capPath];
      }

      await interaction.editReply(payload);
    } catch (error) {
      await interaction.editReply({ content: `Failed: ${friendlyError(error)}` });
    }
  },
};
