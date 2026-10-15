// Exercise the FTP path used by Pi's proxy agent without external services.
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const { createRequire } = require('node:module');
const net = require('node:net');
const path = require('node:path');

if (process.argv[2] !== '--worker') {
  const result = spawnSync(process.execPath, [__filename, '--worker', process.argv[2]], {
    timeout: 10000,
    encoding: 'utf8',
  });
  process.stdout.write(result.stdout || '');
  process.stderr.write(result.stderr || '');
  if (result.error) throw result.error;
  assert.equal(result.status, 0, 'FTP compatibility and hostile-listing regression');
} else {
  const requirePi = createRequire(path.join(process.argv[3], 'package.json'));
  const { getUri } = requirePi('get-uri');
  const { Client } = requirePi('basic-ftp');

  async function fixture(listing, run) {
    const connections = new Set();
    const passiveServers = new Set();
    const server = net.createServer((control) => {
      connections.add(control);
      control.on('close', () => connections.delete(control));
      control.setEncoding('utf8');
      control.write('220 fixture ready\r\n');
      let buffer = '';
      let dataReady;
      control.on('data', (data) => {
        buffer += data;
        let end;
        while ((end = buffer.indexOf('\r\n')) >= 0) {
          const line = buffer.slice(0, end);
          buffer = buffer.slice(end + 2);
          const command = line.split(' ')[0].toUpperCase();
          switch (command) {
            case 'USER': control.write('331 password required\r\n'); break;
            case 'PASS': control.write('230 logged in\r\n'); break;
            case 'FEAT': control.write('211 no features\r\n'); break;
            case 'MDTM': control.write('500 use LIST fallback\r\n'); break;
            case 'EPSV': {
              let resolveData;
              dataReady = new Promise((resolve) => { resolveData = resolve; });
              const passive = net.createServer((socket) => {
                connections.add(socket);
                socket.on('close', () => connections.delete(socket));
                resolveData(socket);
                passive.close();
                passiveServers.delete(passive);
              });
              passiveServers.add(passive);
              passive.listen(0, '127.0.0.1', () => {
                control.write(`229 Entering Extended Passive Mode (|||${passive.address().port}|)\r\n`);
              });
              break;
            }
            case 'LIST':
            case 'MLSD':
            case 'RETR':
              control.write('150 data transfer\r\n');
              dataReady.then((socket) => {
                socket.end(command === 'RETR' ? 'synthetic PAC content\n' : listing, () => {
                  control.write('226 transfer complete\r\n');
                });
              });
              break;
            case 'QUIT': control.end('221 goodbye\r\n'); break;
            default: control.write('200 OK\r\n');
          }
        }
      });
    });
    await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
    try {
      await run(server.address().port);
    } finally {
      for (const socket of connections) socket.destroy();
      for (const passive of passiveServers) passive.close();
      await new Promise((resolve) => server.close(resolve));
    }
  }

  async function main() {
    const valid = '-rw-r--r-- 1 owner group 22 Jan 1 2020 proxy.pac\r\n';
    // Machine-readable listings supply modifiedAt for get-uri's MDTM fallback.
    await fixture('type=file;size=22;modify=20200101000000; proxy.pac\r\n', async (port) => {
      const stream = await getUri(new URL(`ftp://fixture:fixture@127.0.0.1:${port}/proxy.pac`));
      const chunks = [];
      for await (const chunk of stream) chunks.push(chunk);
      assert.equal(Buffer.concat(chunks).toString(), 'synthetic PAC content\n');
    });
    console.log('PASS: get-uri FTP download through LIST fallback');

    const hostile = '-rw-r--r-- 1 ' + 'a '.repeat(64 * 1024) + '!\r\n';
    await fixture(hostile + valid, async (port) => {
      const client = new Client(5000);
      try {
        await client.access({ host: '127.0.0.1', port, user: 'fixture', password: 'fixture' });
        // Rejecting malformed input is also safe; the parent bounds parser CPU time.
        try { await client.list(); } catch (error) {
          assert.match(error.message, /parse|line|listing|format|invalid/i);
        }
      } finally { client.close(); }
    });
    console.log('PASS: hostile FTP listing does not pin the event loop');
  }
  main().catch((error) => { console.error(error); process.exitCode = 1; });
}
