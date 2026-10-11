import { test } from "node:test";
import assert from "node:assert/strict";

import { RefineLoader } from "./loader.ts";

const THEME = {
  fg: (_color: string, text: string) => text,
  bg: (_color: string, text: string) => text,
  bold: (text: string) => text,
};

function makeTui() {
  const renders: number[] = [];
  return { tui: { requestRender: () => renders.push(Date.now()), setFocus: () => {} }, renders };
}

test("the loader animates and reports elapsed time", async () => {
  const { tui, renders } = makeTui();
  const loader = new RefineLoader(tui as never, THEME as never, "Refining with cp");

  const first = loader.render(80).join("\n");
  assert.match(first, /Refining with cp/);
  assert.match(first, /0\.\ds/);
  assert.match(first, /Esc cancels/);

  const rendersAfterStart = renders.length;
  await new Promise((resolve) => setTimeout(resolve, 180));
  assert.ok(renders.length > rendersAfterStart, "the spinner must request a re-render");

  loader.dispose();
});

test("dispose stops the animation", async () => {
  const { tui, renders } = makeTui();
  const loader = new RefineLoader(tui as never, THEME as never, "Refining");

  await new Promise((resolve) => setTimeout(resolve, 100));
  loader.dispose();
  const settled = renders.length;
  await new Promise((resolve) => setTimeout(resolve, 150));

  assert.equal(renders.length, settled, "no renders may happen after dispose");
});

test("escape aborts the signal and calls onAbort exactly once", () => {
  const { tui } = makeTui();
  const loader = new RefineLoader(tui as never, THEME as never, "Refining");

  let aborts = 0;
  loader.onAbort = () => {
    aborts += 1;
  };

  assert.equal(loader.signal.aborted, false);
  loader.handleInput("\u001b");
  assert.equal(loader.signal.aborted, true);
  assert.equal(loader.aborted, true);
  assert.equal(aborts, 1);

  // A second escape must not fire the callback again.
  loader.handleInput("\u001b");
  assert.equal(aborts, 1);

  loader.dispose();
});

test("ordinary keys do not abort", () => {
  const { tui } = makeTui();
  const loader = new RefineLoader(tui as never, THEME as never, "Refining");

  for (const key of ["a", "\r", "\u001b[A"]) loader.handleInput(key);
  assert.equal(loader.signal.aborted, false);
  assert.equal(loader.aborted, false);

  loader.dispose();
});
