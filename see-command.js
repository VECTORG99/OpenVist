/**
 * OpenVist - Discord bot "/see" command
 *
 * Integration example for Discord.js bots.
 * Add this file to your bot's commands directory and register it.
 */

import { SlashCommandBuilder } from 'discord.js';
import { execSync } from 'node:child_process';
import { existsSync, readFileSync, unlinkSync } from 'node:fs';

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
        `${process.env.HOME}/.local/bin/opencode-see ${mode}`,
        { timeout: 120000, encoding: 'utf8', maxBuffer: 10 * 1024 * 1024 }
      );

      const ssPathFile = '/tmp/opencode-latest-ss-path';
      let capPath = null;

      if (existsSync(ssPathFile)) {
        capPath = readFileSync(ssPathFile, 'utf8').trim();
        try { unlinkSync(ssPathFile); } catch {}
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
