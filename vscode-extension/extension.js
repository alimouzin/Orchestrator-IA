// Surveille <workspace>/.git/orchestrator-inbox/*.txt : chaque ligne du fichier est tapée
// dans le terminal « Claude … » (texte, courte pause, puis Entrée), une ligne après l'autre.
const vscode = require('vscode');
const fs = require('fs');
const path = require('path');

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
let queue = Promise.resolve();

function findClaudeTerminal() {
  const ts = vscode.window.terminals;
  return ts.find((t) => /claude/i.test(t.name) && !/watch/i.test(t.name)) || null;
}

async function deliver(file, out) {
  let text;
  try {
    text = fs.readFileSync(file, 'utf8');
    fs.unlinkSync(file);
  } catch (e) {
    return; // déjà traité
  }
  const lines = text.split(/\r?\n/).map((l) => l.trim()).filter(Boolean);
  const term = findClaudeTerminal();
  if (!term) {
    out.appendLine('Aucun terminal « Claude » trouvé, message perdu : ' + lines.join(' | '));
    vscode.window.showWarningMessage('Orchestrator Bridge : aucun terminal « Claude » ouvert.');
    return;
  }
  term.show(true);
  for (const line of lines) {
    if (line === '<ESC>') {
      out.appendLine('> [Échap : interruption]');
      term.sendText('\x1b', false);
      await sleep(1200);
      continue;
    }
    out.appendLine('> ' + line);
    term.sendText(line, false);
    await sleep(400);
    term.sendText('', true); // Entrée séparée, pour ne pas être pris pour un collage
    await sleep(line.startsWith('/') ? 3000 : 1500);
  }
}

function activate(ctx) {
  const out = vscode.window.createOutputChannel('Orchestrator Bridge');
  for (const f of vscode.workspace.workspaceFolders || []) {
    const inbox = path.join(f.uri.fsPath, '.git', 'orchestrator-inbox');
    try { fs.mkdirSync(inbox, { recursive: true }); } catch (e) { out.appendLine('mkdir: ' + e.message); continue; }
    const handle = (name) => {
      if (!name || !name.endsWith('.txt')) return;
      queue = queue.then(() => deliver(path.join(inbox, name), out)).catch((e) => out.appendLine('erreur: ' + e.message));
    };
    const w = fs.watch(inbox, (_ev, name) => setTimeout(() => handle(name), 200));
    ctx.subscriptions.push({ dispose: () => w.close() });
    fs.readdirSync(inbox).forEach(handle);
    out.appendLine('Surveillance de ' + inbox);
  }
}

function deactivate() {}
module.exports = { activate, deactivate };
