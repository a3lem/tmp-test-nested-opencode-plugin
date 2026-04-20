# Bundling Skills in OpenCode Plugins

> A specification for distributing skills as part of npm plugin packages

**Status**: Stable
**Updated**: 2026-02-03

## Overview

This specification describes how to bundle skill files (SKILL.md) within npm plugin packages, allowing skills to be distributed alongside plugin code without writing files to the user's project directories.

### Why Bundle Skills?

- **Self-contained distribution**: Skills ship with the plugin, no separate installation
- **No breadcrumbs**: Zero files written to `.opencode/` or project directories
- **Location-agnostic**: Works regardless of where npm installs the package
- **Version controlled**: Skills update with plugin version
- **Clean uninstall**: Remove plugin = remove skills

## Architecture

### How It Works

1. **Plugin discovers its own location** using `import.meta.url`
2. **Points config** to a `skills/` subdirectory within the package
3. **OpenCode scans** that directory for SKILL.md files
4. **No files written** - skills read directly from npm package

### Resolution Flow

```
Plugin Config Hook
  │
  ├─ import.meta.url → file:///path/to/plugin/dist/index.js
  │
  ├─ path.dirname() → /path/to/plugin/dist/
  │
  ├─ path.join(dist, "skills") → /path/to/plugin/dist/skills/
  │
  └─ config.skills.paths.push(skillsPath)
     config.skill.paths.push(skillsPath)  # legacy key compatibility
       │
       └─ OpenCode scans for SKILL.md files
```

**Works across all npm install locations:**

- `~/.opencode/cache/node_modules/my-plugin/`
- `~/.bun/install/cache/.../my-plugin/`
- `/project/node_modules/my-plugin/`
- Global npm packages

## Package Structure

### Minimal Structure

```
my-plugin/
├── src/
│   └── index.ts          # Plugin entry point
├── skills/               # ← Bundled skills (root level)
│   └── my-skill/
│       └── SKILL.md
├── dist/                 # Compiled output
│   ├── index.js
│   ├── index.d.ts
│   └── skills/           # ← Copied from root during build
│       └── my-skill/
│           └── SKILL.md
├── package.json
├── tsconfig.json
└── build.ts              # Optional: copy skills to dist/
```

### Alternative: Skills in dist/

```
my-plugin/
├── src/
│   └── index.ts
├── dist-skills/          # Skills live here directly
│   └── my-skill/
│       └── SKILL.md
├── package.json
└── tsconfig.json
```

Then reference `../dist-skills` from compiled code.

## Implementation

### Config Key Compatibility

Register bundled skill paths on both `config.skills.paths` and `config.skill.paths` to support older/alternate config keys.

### Basic Plugin

```typescript
import type { Plugin } from "@opencode-ai/plugin";
import path from "path";
import { fileURLToPath } from "node:url";

// Resolves to plugin's install location
const __dirname = path.dirname(fileURLToPath(import.meta.url));

export const SkillPlugin: Plugin = async () => {
  return {
    config: async (config) => {
      // Path to skills/ relative to plugin install location
      const skillPath = path.join(__dirname, "skills");

      config.skills = config.skills || {};
      config.skills.paths = config.skills.paths || [];
      config.skills.paths.push(skillPath);
      config.skill = config.skill || {};
      config.skill.paths = config.skill.paths || [];
      config.skill.paths.push(skillPath);
      config.skill = config.skill || {};
      config.skill.paths = config.skill.paths || [];
      config.skill.paths.push(skillPath);
      config.skill = config.skill || {};
      config.skill.paths = config.skill.paths || [];
      config.skill.paths.push(skillPath);
    },
  };
};
```

### With Multiple Skills

```typescript
import type { Plugin } from "@opencode-ai/plugin";
import path from "path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

export const MultiSkillPlugin: Plugin = async ({ log }) => {
  return {
    config: async (config) => {
      const skillPath = path.join(__dirname, "skills");

      // Optional: Validate skills exist
      const fs = await import("fs/promises");
      try {
        const files = await fs.readdir(skillPath);
        log?.info(`Registering ${files.length} skills from plugin`, {
          path: skillPath,
        });
      } catch {
        log?.warn("Skills directory not found", { path: skillPath });
      }

      config.skills = config.skills || {};
      config.skills.paths = config.skills.paths || [];
      config.skills.paths.push(skillPath);
    },
  };
};
```

### TypeScript Config

**tsconfig.json** - ensure assets are handled:

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "rootDir": "./src",
    "outDir": "./dist"
  },
  "include": ["src/**/*"],
  "ts-node": {
    "compilerOptions": {
      "module": "ESNext"
    }
  }
}
```

### Build Script

**build.ts** - copy skills to dist/:

```typescript
import { $ } from "bun";

console.log("Building plugin...");

// 1. Compile TypeScript
await $`tsc`;

// 2. Copy skills to dist/
await $`cp -r skills dist/`;

console.log("Build complete!");
```

**Or in package.json**:

```json
{
  "scripts": {
    "build": "tsc && cp -r skills dist/",
    "prepublishOnly": "bun run build"
  }
}
```

### package.json

```json
{
  "name": "my-skill-plugin",
  "version": "1.0.0",
  "type": "module",
  "main": "dist/index.js",
  "types": "dist/index.d.ts",
  "files": ["dist/**/*", "skills/**/*", "README.md", "LICENSE"],
  "peerDependencies": {
    "@opencode-ai/plugin": "^1.0.0"
  },
  "scripts": {
    "build": "tsc && cp -r skills dist/",
    "prepublishOnly": "bun run build"
  }
}
```

**Important**: Include `"skills/**/*"` in `files` array if skills live at root.

## Installation

### User Installation

Users add plugin to `opencode.json`:

```json
{
  "plugin": ["my-skill-plugin"]
}
```

OpenCode automatically:

1. Installs the npm package
2. Loads the plugin
3. Scans the bundled `skills/` directory
4. Makes skills available to agents

### Verification

After installation, verify skills are loaded:

```bash
# In OpenCode session
/which skills

# Should show your bundled skills
```

## Migration Guide

### From External Skills

**Before** (separate skill installation):

```bash
# User had to install skills manually
mkdir -p .opencode/skills/my-skill
# copy SKILL.md...
```

**After** (bundled with plugin):

```typescript
// Old plugin
export const OldPlugin: Plugin = async () => {
  return {
    // No skill registration
  };
};

// New plugin
import type { Plugin } from "@opencode-ai/plugin";
import path from "path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

export const NewPlugin: Plugin = async () => {
  return {
    config: async (config) => {
      const skillPath = path.join(__dirname, "skills");
      config.skills = config.skills || {};
      config.skills.paths = config.skills.paths || [];
      config.skills.paths.push(skillPath);
    },
  };
};
```

### Migration Steps

1. **Create `skills/` directory** in plugin package
2. **Move SKILL.md files** from external locations to `skills/`
3. **Update plugin code** to register skill path (see Implementation)
4. **Update build script** to copy skills to `dist/`
5. **Update package.json** `files` array to include skills
6. **Bump version** and publish
7. **Update documentation** to remove manual skill installation steps

### From Runtime-Created Skills

**Before** (writing temp files):

```typescript
// AVOID: Writes breadcrumbs
export const OldPlugin: Plugin = async () => {
  const SKILL_MD = `...`;
  const tmpDir = `/tmp/my-plugin-skills`;
  await fs.mkdir(tmpDir, { recursive: true });
  await fs.writeFile(path.join(tmpDir, "SKILL.md"), SKILL_MD);

  return {
    config: async (config) => {
      config.skills?.paths?.push(tmpDir);
    },
  };
};
```

**After** (bundled, no file writes):

```typescript
// PREFERRED: No temp files
const __dirname = path.dirname(fileURLToPath(import.meta.url));

export const NewPlugin: Plugin = async () => {
  return {
    config: async (config) => {
      const skillPath = path.join(__dirname, "skills");
      config.skills = config.skills || {};
      config.skills.paths = config.skills.paths || [];
      config.skills.paths.push(skillPath);
    },
  };
};
```

## Best Practices

### DO ✓

- **Bundle skills with plugin**: Keeps distribution simple
- **Use `import.meta.url`**: Works across all install locations
- **Validate in dev**: Check skills exist during development
- **Document skills**: List bundled skills in README
- **Version together**: Skills update with plugin releases
- **Clean structure**: One skill per subdirectory

### DON'T ✗

- **Write to `.opencode/`**: Leaves breadcrumbs
- **Write to temp dirs**: Unnecessary complexity
- **Hardcode paths**: Breaks across different install locations
- **Assume install location**: Use `import.meta.url` instead
- **Forget build step**: Skills must be copied to `dist/`

## Examples

### Example 1: Single Skill Plugin

```
opencode-my-skill/
├── src/
│   └── index.ts
├── skills/
│   └── my-skill/
│       └── SKILL.md
├── dist/
│   ├── index.js
│   └── skills/
│       └── my-skill/
│           └── SKILL.md
└── package.json
```

**src/index.ts**:

```typescript
import type { Plugin } from "@opencode-ai/plugin";
import path from "path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

export const mySkillPlugin: Plugin = async () => ({
  config: async (config) => {
    config.skills = config.skills || {};
    config.skills.paths = config.skills.paths || [];
    config.skills.paths.push(path.join(__dirname, "skills"));
  },
});
```

### Example 2: Multi-Skill Toolkit

```
opencode-toolkit/
├── src/
│   ├── index.ts
│   └── tools.ts
├── skills/
│   ├── planning/
│   │   └── SKILL.md
│   ├── debugging/
│   │   └── SKILL.md
│   └── refactoring/
│       └── SKILL.md
└── package.json
```

**src/index.ts**:

```typescript
import type { Plugin } from "@opencode-ai/plugin";
import path from "path";
import { fileURLToPath } from "node:url";
import { customTools } from "./tools";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

export const toolkitPlugin: Plugin = async ({ log }) => ({
  config: async (config) => {
    const skillPath = path.join(__dirname, "skills");

    // Log what we're registering
    const fs = await import("fs/promises");
    const dirs = await fs.readdir(skillPath).catch(() => []);
    log?.info(`Registering ${dirs.length} toolkit skills`, { path: skillPath });

    config.skills = config.skills || {};
    config.skills.paths = config.skills.paths || [];
    config.skills.paths.push(skillPath);
  },
  tool: customTools,
});
```

## Troubleshooting

### Skills Not Found

**Symptom**: Plugin loads but skills unavailable

**Debug**:

```typescript
config: async (config) => {
  const skillPath = path.join(__dirname, "skills");
  console.log("[DEBUG] Registering skills:", skillPath);

  const fs = await import("fs/promises");
  const exists = await fs
    .access(skillPath)
    .then(() => true)
    .catch(() => false);
  console.log("[DEBUG] Skills exists:", exists);

  if (exists) {
    const files = await fs.readdir(skillPath);
    console.log("[DEBUG] Skills contents:", files);
  }

  config.skills = config.skills || {};
  config.skills.paths = config.skills.paths || [];
  config.skills.paths.push(skillPath);
  config.skill = config.skill || {};
  config.skill.paths = config.skill.paths || [];
  config.skill.paths.push(skillPath);
};
```

**Common causes**:

- Build script doesn't copy skills to `dist/`
- `package.json` `files` array doesn't include skills
- Wrong path in `import.meta.url` resolution
- `opencode.json` points to `src/index.ts` instead of `dist/index.js`

### Path Resolution Issues

**Test** your plugin from different install locations:

```bash
# Test local file:// load
opencode.json: { "plugin": ["file:///path/to/plugin/dist/index.js"] }

# Test npm install
opencode.json: { "plugin": ["my-plugin"] }
```

Both should work with same `import.meta.url` pattern.

## Version Compatibility

- **OpenCode**: v1.0.0+ (plugin support)
- **@opencode-ai/plugin**: v1.0.0+
- **Node**: Supports ES modules (`import.meta.url`)

## Related Specifications

- [OpenCode Plugin SDK](https://opencode.ai/docs/plugins)
- [Skill Format Specification](https://opencode.ai/docs/skills)
- [Config Precedence](https://opencode.ai/docs/config#precedence-order)

## Changelog

### 2026-02-03

- Initial specification
- Document `import.meta.url` pattern
- Migration guide from external/temp skills
