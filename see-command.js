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
 */

import { SlashCommandBuilder } from 'discord.js';
import { execSync } from 'node:child_process';
import { existsSync, readFileSync, unlinkSync } from 'node:fs';
import { homedir } from 'node:os';

const SEE_SCRIPT = process.env.OPENCODE_SEE_PATH
  || `${homedir()}/.local/bin/opencode-see`;
const SS_PATH_FILE = process.env.OPENCODE_SS_PATH
  || `${process.env.XDG_RUNTIME_DIR || '/tmp'}/opencode-latest-ss-path`;

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
        )),

  async execute(interaction) {
    const mode = interaction.options.getString('mode') || 'full';
    await interaction.deferReply();

    try {
      const output = execSync(
        `${JSON.stringify(SEE_SCRIPT)} ${mode}`,
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
