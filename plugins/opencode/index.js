import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

/**
 * OpenCode plugin: registers the bundled skills/ directory so OpenCode
 * discovers all SKILL.md files shipped with this package.
 *
 * Install from a GitHub monorepo:
 *   { "plugin": ["github:user/repo#main&path:plugins/opencode"] }
 */
export const SpexlSkillsPlugin = async () => ({
  config: async (config) => {
    const skillPath = path.join(__dirname, "skills");

    // Current key
    config.skills = config.skills || {};
    config.skills.paths = config.skills.paths || [];
    config.skills.paths.push(skillPath);

    // Legacy key compatibility
    config.skill = config.skill || {};
    config.skill.paths = config.skill.paths || [];
    config.skill.paths.push(skillPath);
  },
});
