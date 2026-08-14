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

export const see = {
  data: new SlashCommandBuilder()
    .setName('see')
    .setDescription('Take a screenshot and describe what is on screen')
    .addStringOption(option =>
      option.setName('mode')
        .setDescription('Capture mode')
        .setRequired(false)
        .addChoices(
          { name: 'Both monitors', value: 'full' },
          { name: 'Left monitor', value: 'left' },
          { name: 'Right monitor', value: 'right' },
          { name: 'Region select', value: 'region' },
          { name: 'Active window', value: 'window' },
        ))
    .addStringOption(option =>
      option.setName('prompt')
        .setDescription('Custom prompt for the vision model')
        .setRequired(false))
    .addStringOption(option =>
      option.setName('template')
        .setDescription('Prompt template to use')
        .setRequired(false)
        .addChoices(...PROMPT_TEMPLATES)),

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

    const mode = interaction.options.getString('mode') || 'full';
    const customPrompt = interaction.options.getString('prompt');
    const template = interaction.options.getString('template');

    await interaction.deferReply();

    // Build the command-line arguments safely.
    const args = [JSON.stringify(SEE_SCRIPT)];

    if (template) {
      args.push('--prompt-template', JSON.stringify(template));
    }

    args.push(JSON.stringify(mode));

    if (customPrompt) {
      args.push(JSON.stringify(customPrompt));
    }

    try {
      const output = execSync(
        args.join(' '),
        { timeout: 120000, encoding: 'utf8', maxBuffer: 10 * 1024 * 1024 }
      );

      let capPath = null;

      if (existsSync(SS_PATH_FILE)) {
        capPath = readFileSync(SS_PATH_FILE, 'utf8').trim();
        try { unlinkSync(SS_PATH_FILE); } catch {}
      }

      const lines = output.trim().split('\n');
      const markerIdx = lines.findIndex(l => l.startsWith('Screen capture:'));
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
      const msg = error.stderr?.toString().trim() || error.message || 'Unknown error';
      await interaction.editReply({ content: `Failed: ${msg}` });
    }
  },
};
