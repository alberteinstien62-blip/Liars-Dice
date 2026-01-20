const { chromium } = require('playwright');

/**
 * JUDGE CHAOS TEST - Simulates a judge who:
 * 1. Has only 2 minutes
 * 2. Doesn't read docs
 * 3. Clicks randomly
 * 4. Reloads mid-flow
 * 5. Tries to break things
 */

(async () => {
  const browser = await chromium.launch({ headless: false });
  const startTime = Date.now();
  const results = {
    dockerStartup: 'ALREADY RUNNING',
    uiLoads: false,
    canStartWithoutDocs: false,
    pageReloadWorks: false,
    errorMessagesHelpful: true,
    multiplayerWorks: false,
    consoleErrors: [],
    criticalFailures: []
  };

  console.log('='.repeat(60));
  console.log('JUDGE CHAOS TEST - Liar\'s Dice');
  console.log('='.repeat(60));
  console.log('Simulating: Judge with 2 minutes, no docs, chaos clicking\n');

  const contextA = await browser.newContext();
  const contextB = await browser.newContext();

  const pageA = await contextA.newPage();
  const pageB = await contextB.newPage();

  // Capture console errors
  pageA.on('console', msg => {
    if (msg.type() === 'error') results.consoleErrors.push(`A: ${msg.text()}`);
  });
  pageB.on('console', msg => {
    if (msg.type() === 'error') results.consoleErrors.push(`B: ${msg.text()}`);
  });

  try {
    // TEST 1: UI Loads without error
    console.log('TEST 1: UI loads without error');
    await pageA.goto('http://localhost:5173', { timeout: 10000 });
    await pageB.goto('http://localhost:5174', { timeout: 10000 });
    await new Promise(r => setTimeout(r, 2000));

    const bodyA = await pageA.textContent('body');
    if (bodyA.includes('Liar') || bodyA.includes('Dice') || bodyA.includes('Profile')) {
      results.uiLoads = true;
      console.log('   PASS: UI loaded successfully\n');
    } else {
      results.criticalFailures.push('UI did not load properly');
      console.log('   FAIL: UI did not load\n');
    }

    // TEST 2: Can start game WITHOUT reading docs
    console.log('TEST 2: Can start game without reading docs');

    // Look for obvious buttons
    const buttons = await pageA.$$('button');
    console.log(`   Found ${buttons.length} buttons`);

    // Find input and enter name
    const inputs = await pageA.$$('input');
    if (inputs.length > 0) {
      await inputs[0].fill('ChaosJudge');
      console.log('   Entered name: ChaosJudge');
    }

    // Click the most obvious button (CREATE PROFILE)
    try {
      await pageA.click('button:has-text("CREATE PROFILE")', { timeout: 3000 });
      console.log('   Clicked CREATE PROFILE');
      await new Promise(r => setTimeout(r, 2000));
      results.canStartWithoutDocs = true;
    } catch {
      results.criticalFailures.push('Could not find obvious CREATE PROFILE button');
      console.log('   Could not find CREATE PROFILE button');
    }

    // Same for player B
    await pageB.fill('input[type="text"]', 'ChaosJudge2');
    await pageB.click('button:has-text("CREATE PROFILE")').catch(() => {});
    await new Promise(r => setTimeout(r, 2000));

    // TEST 3: Page reload mid-flow
    console.log('\nTEST 3: Page reload mid-flow');
    await pageA.reload();
    await new Promise(r => setTimeout(r, 3000));

    const bodyAfterReload = await pageA.textContent('body');
    if (bodyAfterReload.includes('Liar') || bodyAfterReload.includes('Dice')) {
      results.pageReloadWorks = true;
      console.log('   PASS: Page still works after reload\n');
    } else {
      results.criticalFailures.push('Page broke after reload');
      console.log('   FAIL: Page broke after reload\n');
    }

    // TEST 4: Connect to lobby and find match
    console.log('TEST 4: Multiplayer matchmaking');

    // Re-create profile after reload
    const inputsAfter = await pageA.$$('input');
    if (inputsAfter.length > 0) {
      await inputsAfter[0].fill('ChaosJudge');
      await pageA.click('button:has-text("CREATE PROFILE")').catch(() => {});
      await new Promise(r => setTimeout(r, 2000));
    }

    // Connect to lobby
    await pageA.click('button:has-text("CONNECT TO LOBBY")').catch(() => {});
    await pageB.click('button:has-text("CONNECT TO LOBBY")').catch(() => {});
    await new Promise(r => setTimeout(r, 2000));

    // Find match
    await pageA.click('button:has-text("FIND MATCH")').catch(() => {});
    await pageB.click('button:has-text("FIND MATCH")').catch(() => {});

    // Wait for match
    console.log('   Waiting for match (max 20 seconds)...');
    for (let i = 0; i < 20; i++) {
      await new Promise(r => setTimeout(r, 1000));
      const bodyCheck = await pageA.textContent('body');
      if (bodyCheck.includes('YOUR TURN') || bodyCheck.includes('WAITING')) {
        results.multiplayerWorks = true;
        console.log(`   PASS: Match found in ${i + 1} seconds!\n`);
        break;
      }
    }

    if (!results.multiplayerWorks) {
      results.criticalFailures.push('Matchmaking failed within 20 seconds');
      console.log('   FAIL: Matchmaking did not work\n');
    }

    // TEST 5: Random clicking (chaos)
    console.log('TEST 5: Chaos clicking (trying to break things)');

    // Click random places
    const allButtons = await pageA.$$('button');
    for (let i = 0; i < Math.min(3, allButtons.length); i++) {
      try {
        await allButtons[i].click({ timeout: 1000 });
        await new Promise(r => setTimeout(r, 500));
      } catch {}
    }

    // Check if page is still functional
    const bodyAfterChaos = await pageA.textContent('body');
    if (bodyAfterChaos.length > 100) {
      console.log('   PASS: App survived chaos clicking\n');
    } else {
      results.criticalFailures.push('App crashed during chaos clicking');
      console.log('   FAIL: App crashed\n');
    }

    // Take screenshots
    await pageA.screenshot({ path: 'tests/e2e/chaos_player_a.png' });
    await pageB.screenshot({ path: 'tests/e2e/chaos_player_b.png' });

  } catch (e) {
    results.criticalFailures.push(`Test error: ${e.message}`);
    console.log(`ERROR: ${e.message}`);
  }

  // Calculate elapsed time
  const elapsed = Math.round((Date.now() - startTime) / 1000);

  // FINAL REPORT
  console.log('\n' + '='.repeat(60));
  console.log('JUDGE CHAOS TEST RESULTS');
  console.log('='.repeat(60));
  console.log(`Time elapsed: ${elapsed} seconds`);
  console.log('');
  console.log(`UI Loads:              ${results.uiLoads ? 'PASS' : 'FAIL'}`);
  console.log(`Start Without Docs:    ${results.canStartWithoutDocs ? 'PASS' : 'FAIL'}`);
  console.log(`Page Reload Works:     ${results.pageReloadWorks ? 'PASS' : 'FAIL'}`);
  console.log(`Multiplayer Works:     ${results.multiplayerWorks ? 'PASS' : 'FAIL'}`);
  console.log(`Console Errors:        ${results.consoleErrors.length === 0 ? 'NONE' : results.consoleErrors.length}`);
  console.log('');

  if (results.criticalFailures.length > 0) {
    console.log('CRITICAL FAILURES:');
    results.criticalFailures.forEach(f => console.log(`  - ${f}`));
  }

  const passCount = [
    results.uiLoads,
    results.canStartWithoutDocs,
    results.pageReloadWorks,
    results.multiplayerWorks,
    results.consoleErrors.length === 0
  ].filter(Boolean).length;

  console.log('');
  console.log(`OVERALL SCORE: ${passCount}/5 tests passed`);
  console.log(passCount >= 4 ? 'VERDICT: JUDGE-PROOF' : 'VERDICT: NEEDS WORK');
  console.log('='.repeat(60));

  await new Promise(r => setTimeout(r, 3000));
  await browser.close();
})();
