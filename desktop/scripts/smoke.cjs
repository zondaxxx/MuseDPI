const path = require('node:path');
const { Controller } = require('../controller.cjs');

async function main() {
  const engine = process.env.MUSE_TEST_ENGINE || path.resolve(__dirname, '..', 'engine', process.platform === 'win32' ? 'ciadpi.exe' : 'ciadpi');
  const controller = new Controller(engine);
  try {
    await controller.start('gentle');
    const results = await controller.diagnose();
    console.log(JSON.stringify({ profile: controller.state.profile, results }, null, 2));
    if (!results.every(result => result.reachable)) process.exitCode = 1;
  } finally { await controller.close(); }
}
main().catch(error => { console.error(error.message); process.exitCode = 1; });
