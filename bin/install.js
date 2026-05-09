#!/usr/bin/env node

const fs = require("fs");
const os = require("os");
const path = require("path");
const { execSync } = require("child_process");

const CLAUDE_DIR = path.join(os.homedir(), ".claude");
const SETTINGS_FILE = path.join(CLAUDE_DIR, "settings.json");
const STATUSLINE_DEST = path.join(CLAUDE_DIR, "statusline.sh");
const STATUSLINE_SRC = path.join(__dirname, "statusline.sh");

const blue = "\x1b[38;2;88;166;255m";
const green = "\x1b[38;2;81;207;102m";
const yellow = "\x1b[38;2;235;190;80m";
const red = "\x1b[38;2;255;91;91m";
const dim = "\x1b[2m";
const reset = "\x1b[0m";

function say(message) {
  console.log(`  ${message}`);
}

function ok(message) {
  say(`${green}OK${reset} ${message}`);
}

function warn(message) {
  say(`${yellow}!${reset} ${message}`);
}

function fail(message) {
  console.error(`  ${red}ERR${reset} ${message}`);
}

function has(command) {
  try {
    execSync(`command -v ${command}`, { stdio: "ignore", shell: "/bin/sh" });
    return true;
  } catch {
    return false;
  }
}

function readSettings() {
  if (!fs.existsSync(SETTINGS_FILE)) return {};
  try {
    return JSON.parse(fs.readFileSync(SETTINGS_FILE, "utf8"));
  } catch {
    fail(`Could not parse ${SETTINGS_FILE}`);
    process.exit(1);
  }
}

function writeSettings(settings) {
  fs.writeFileSync(SETTINGS_FILE, JSON.stringify(settings, null, 2) + "\n");
}

function uninstall() {
  console.log(`\n  ${blue}model-agent-status uninstall${reset}\n`);
  const backup = `${STATUSLINE_DEST}.model-agent-status.bak`;

  if (fs.existsSync(backup)) {
    fs.copyFileSync(backup, STATUSLINE_DEST);
    fs.unlinkSync(backup);
    ok("restored previous statusline");
  } else if (fs.existsSync(STATUSLINE_DEST)) {
    fs.unlinkSync(STATUSLINE_DEST);
    ok("removed statusline script");
  } else {
    warn("no statusline script found");
  }

  if (fs.existsSync(SETTINGS_FILE)) {
    const settings = readSettings();
    if (settings.statusLine) {
      delete settings.statusLine;
      writeSettings(settings);
      ok("removed statusLine from settings.json");
    }
  }
}

function install() {
  console.log(`\n  ${blue}model-agent-status install${reset}\n`);

  const missing = ["jq", "curl", "git"].filter((cmd) => !has(cmd));
  if (missing.length) {
    fail(`missing dependencies: ${missing.join(", ")}`);
    process.exit(1);
  }
  ok("dependencies found");

  fs.mkdirSync(CLAUDE_DIR, { recursive: true });

  const backup = `${STATUSLINE_DEST}.model-agent-status.bak`;
  if (fs.existsSync(STATUSLINE_DEST) && !fs.existsSync(backup)) {
    fs.copyFileSync(STATUSLINE_DEST, backup);
    warn(`backed up previous statusline to ${dim}${backup}${reset}`);
  }

  fs.copyFileSync(STATUSLINE_SRC, STATUSLINE_DEST);
  fs.chmodSync(STATUSLINE_DEST, 0o755);
  ok(`installed ${dim}${STATUSLINE_DEST}${reset}`);

  const settings = readSettings();
  settings.statusLine = {
    type: "command",
    command: 'bash "$HOME/.claude/statusline.sh"',
  };
  writeSettings(settings);
  ok("updated Claude Code settings");

  console.log();
  say("Restart Claude Code to render the new statusline.");
  say(`${dim}GitCode cookie path: ~/.claude/.gitcode_session_cookie${reset}`);
}

function usage() {
  console.log(`
model-agent-status

Usage:
  model-agent-status              Install the statusline
  model-agent-status --uninstall  Remove it and restore backup when available
  model-agent-status --help       Show this help
`);
}

if (process.argv.includes("--help") || process.argv.includes("-h")) {
  usage();
} else if (process.argv.includes("--uninstall")) {
  uninstall();
} else {
  install();
}
