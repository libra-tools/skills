#!/usr/bin/env node
//
// Install this package's Agent Skills into every agent that can read them.
//
//   npx @libra-tools/skills            install globally
//   npx @libra-tools/skills --project  install into the current repository
//   npx @libra-tools/skills uninstall  remove them again
//
// The Node entry point exists so a user can install without cloning the repo,
// without a POSIX shell, and — importantly — without Libra already installed.
// install.sh remains the contributor path: it symlinks a working copy.

import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const PKG_ROOT = path.resolve(HERE, '..');
const SKILLS_DIR = path.join(PKG_ROOT, 'skills');

// Copied from Libra's own embedded skill (src/internal/ai/skills/embedded/libra.md).
// An empty list is accepted but raises a `missing_allowed_tools` scan warning.
const LIBRA_ALLOWED_TOOLS = [
  'read_file', 'list_dir', 'grep_files', 'search_files', 'web_search',
  'shell', 'apply_patch', 'run_libra_vcs', 'update_plan', 'submit_task_complete',
];

const USAGE = `
libra-skills — install cross-agent Agent Skills

Usage:
  npx @libra-tools/skills [install]        install globally (default)
  npx @libra-tools/skills install --project [dir]
  npx @libra-tools/skills uninstall [--project [dir]]

Options:
  --project [dir]  install into a repository instead of the home directory
                   (default: the current directory)
  --copy           copy the files (default on Windows)
  --link           symlink instead of copying (default elsewhere)
  --no-libra       skip the libra-native single-file skill
  --dry-run        print what would happen, change nothing
  -h, --help       this text
  -v, --version    package version
`.trimStart();

function parseArgs(argv) {
  const opts = {
    action: 'install',
    project: null,
    mode: process.platform === 'win32' ? 'copy' : 'link',
    libraNative: true,
    dryRun: false,
  };
  const rest = [];
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    switch (arg) {
      case 'install': case 'uninstall': opts.action = arg; break;
      case '--copy': opts.mode = 'copy'; break;
      case '--link': opts.mode = 'link'; break;
      case '--no-libra': opts.libraNative = false; break;
      case '--dry-run': opts.dryRun = true; break;
      case '-h': case '--help': opts.help = true; break;
      case '-v': case '--version': opts.version = true; break;
      case '--project':
        // An optional value: `--project` alone means the current directory.
        if (argv[i + 1] && !argv[i + 1].startsWith('-')) { opts.project = argv[i + 1]; i += 1; }
        else { opts.project = '.'; }
        break;
      default:
        if (arg.startsWith('--project=')) opts.project = arg.slice('--project='.length);
        else rest.push(arg);
    }
  }
  if (rest.length) {
    console.error(`error: unknown argument '${rest[0]}'\n`);
    console.error(USAGE);
    process.exit(2);
  }
  return opts;
}

function configHome() {
  return process.env.XDG_CONFIG_HOME || path.join(os.homedir(), '.config');
}

// Every directory an agent scans for user-global skills.
function globalTargets() {
  const home = os.homedir();
  return [
    { dir: path.join(home, '.claude', 'skills'), agents: 'Claude Code, opencode' },
    { dir: path.join(home, '.agents', 'skills'), agents: 'Codex CLI, Gemini CLI, opencode' },
    { dir: path.join(home, '.codex', 'skills'), agents: 'Codex CLI' },
    { dir: path.join(home, '.gemini', 'skills'), agents: 'Gemini CLI' },
    { dir: path.join(configHome(), 'opencode', 'skills'), agents: 'opencode' },
  ];
}

function projectTargets(root) {
  return [
    { dir: path.join(root, '.claude', 'skills'), agents: 'Claude Code, opencode' },
    { dir: path.join(root, '.agents', 'skills'), agents: 'Gemini CLI, opencode' },
    { dir: path.join(root, '.codex', 'skills'), agents: 'Codex CLI' },
  ];
}

function listSkills() {
  if (!fs.existsSync(SKILLS_DIR)) {
    console.error(`error: no skills directory in this package (${SKILLS_DIR})`);
    process.exit(1);
  }
  const names = fs.readdirSync(SKILLS_DIR, { withFileTypes: true })
    .filter((e) => e.isDirectory() && fs.existsSync(path.join(SKILLS_DIR, e.name, 'SKILL.md')))
    .map((e) => e.name);
  if (!names.length) {
    console.error(`error: ${SKILLS_DIR} contains no skill directories`);
    process.exit(1);
  }
  return names;
}

// --- YAML frontmatter (the two fields the standard requires) ----------------

function readFrontmatter(skillMd) {
  const text = fs.readFileSync(skillMd, 'utf8');
  const match = /^---\r?\n([\s\S]*?)\r?\n---\r?\n?/.exec(text);
  if (!match) throw new Error(`${skillMd} has no '---' frontmatter block`);
  const fields = {};
  for (const line of match[1].split(/\r?\n/)) {
    const kv = /^([A-Za-z][A-Za-z0-9_-]*):\s*(.*)$/.exec(line);
    if (kv) fields[kv[1]] = kv[2].trim();
  }
  return { fields, body: text.slice(match[0].length) };
}

// --- libra-native single-file skill ----------------------------------------
//
// `libra code` loads <name>.md with TOML frontmatter from ~/.config/libra/skills
// or <repo>/.libra/skills. Its parser uses deny_unknown_fields, so only name,
// description, version and allowed-tools may appear. It has no notion of
// bundled reference files, so they are inlined.

function tomlString(value) {
  return `"${String(value).replace(/\\/g, '\\\\').replace(/"/g, '\\"')}"`;
}

function renderLibraNative(skillName, version) {
  const skillDir = path.join(SKILLS_DIR, skillName);
  const { fields, body } = readFrontmatter(path.join(skillDir, 'SKILL.md'));

  const frontmatter = [
    '---',
    `name = ${tomlString(fields.name || skillName)}`,
    `description = ${tomlString(fields.description || '')}`,
    `version = ${tomlString(version)}`,
    `allowed-tools = [${LIBRA_ALLOWED_TOOLS.map(tomlString).join(', ')}]`,
    '---',
    '',
  ].join('\n');

  // Reference links cannot resolve in a flattened file; keep the link text.
  let flattened = body.replace(/\[([^\]]+)\]\(references\/[^)]+\)/g, '$1');

  const refDir = path.join(skillDir, 'references');
  if (fs.existsSync(refDir)) {
    for (const ref of fs.readdirSync(refDir).filter((f) => f.endsWith('.md')).sort()) {
      flattened += `\n\n---\n\n<!-- inlined from references/${ref} -->\n\n`;
      flattened += fs.readFileSync(path.join(refDir, ref), 'utf8').trim();
      flattened += '\n';
    }
  }
  return frontmatter + flattened.trim() + '\n';
}

// --- filesystem actions -----------------------------------------------------

function makeRunner(dryRun) {
  return {
    mkdir(dir) { if (dryRun) console.log(`  would mkdir -p ${dir}`); else fs.mkdirSync(dir, { recursive: true }); },
    remove(target) { if (dryRun) console.log(`  would rm -rf ${target}`); else fs.rmSync(target, { recursive: true, force: true }); },
    copy(from, to) { if (dryRun) console.log(`  would copy ${from} -> ${to}`); else fs.cpSync(from, to, { recursive: true }); },
    symlink(from, to) {
      if (dryRun) { console.log(`  would symlink ${to} -> ${from}`); return; }
      try {
        fs.symlinkSync(from, to, 'dir');
      } catch (error) {
        if (error.code === 'EPERM' || error.code === 'EACCES') {
          throw new Error(`cannot create a symlink at ${to} (${error.code}) — re-run with --copy`);
        }
        throw error;
      }
    },
    write(file, content) { if (dryRun) console.log(`  would write ${file} (${content.length} bytes)`); else fs.writeFileSync(file, content); },
  };
}

function install(opts, skills, version) {
  const run = makeRunner(opts.dryRun);
  const targets = opts.project === null
    ? globalTargets()
    : projectTargets(path.resolve(opts.project));

  for (const { dir, agents } of targets) {
    run.mkdir(dir);
    for (const name of skills) {
      const dest = path.join(dir, name);
      run.remove(dest);
      if (opts.mode === 'copy') run.copy(path.join(SKILLS_DIR, name), dest);
      else run.symlink(path.join(SKILLS_DIR, name), dest);
      console.log(`${opts.mode === 'copy' ? 'copied  ' : 'linked  '} ${dest}   (${agents})`);
    }
  }

  if (opts.libraNative) {
    // Repository tier is <repo>/.libra/skills, but only inside a real Libra repo.
    const nativeDir = opts.project === null
      ? path.join(configHome(), 'libra', 'skills')
      : path.join(path.resolve(opts.project), '.libra', 'skills');
    if (opts.project !== null && !fs.existsSync(path.join(path.resolve(opts.project), '.libra'))) {
      console.log('skipped   libra-native skill (not a Libra repository)');
    } else {
      run.mkdir(nativeDir);
      for (const name of skills) {
        const dest = path.join(nativeDir, `${name}.md`);
        run.write(dest, renderLibraNative(name, version));
        console.log(`wrote    ${dest}   (libra code)`);
      }
    }
  }

  console.log('');
  console.log(opts.project === null
    ? 'Done. Skills are available to Claude Code, Codex CLI, Gemini CLI and opencode.'
    : 'Done. Skills are available to any supported agent opened in this directory.');
  if (opts.mode === 'copy') console.log('Re-run after upgrading the package to refresh the copies.');
}

function uninstall(opts, skills) {
  const run = makeRunner(opts.dryRun);
  const targets = opts.project === null
    ? globalTargets()
    : projectTargets(path.resolve(opts.project));

  let removed = 0;
  for (const { dir } of targets) {
    for (const name of skills) {
      const dest = path.join(dir, name);
      if (fs.existsSync(dest) || fs.lstatSync(dest, { throwIfNoEntry: false })) {
        run.remove(dest);
        console.log(`removed  ${dest}`);
        removed += 1;
      }
    }
  }

  const nativeDir = opts.project === null
    ? path.join(configHome(), 'libra', 'skills')
    : path.join(path.resolve(opts.project), '.libra', 'skills');
  for (const name of skills) {
    const dest = path.join(nativeDir, `${name}.md`);
    if (fs.existsSync(dest)) { run.remove(dest); console.log(`removed  ${dest}`); removed += 1; }
  }

  console.log('');
  console.log(removed ? 'Uninstalled.' : 'Nothing to uninstall.');
}

function main() {
  const opts = parseArgs(process.argv.slice(2));
  const version = JSON.parse(fs.readFileSync(path.join(PKG_ROOT, 'package.json'), 'utf8')).version;

  if (opts.help) { process.stdout.write(USAGE); return; }
  if (opts.version) { console.log(version); return; }

  const skills = listSkills();
  if (opts.action === 'uninstall') uninstall(opts, skills);
  else install(opts, skills, version);
}

try {
  main();
} catch (error) {
  console.error(`error: ${error.message}`);
  process.exit(1);
}
