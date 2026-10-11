import type { Theme } from "@earendil-works/pi-coding-agent";
import { DynamicBorder } from "@earendil-works/pi-coding-agent";
import { Container, Spacer, Text, type TUI } from "@earendil-works/pi-tui";

/**
 * Braille spinner at ~70 ms per frame. Slightly faster than the built-in 80 ms
 * so short refinements still register as motion rather than a single static
 * frame.
 */
const FRAMES = ["\u280b", "\u2819", "\u2839", "\u2838", "\u283c", "\u2834", "\u2826", "\u2827", "\u2807", "\u280f"];
const FRAME_MS = 70;

/** After this long, add reassurance to the label. */
const SLOW_AFTER_MS = 10_000;

/**
 * Progress widget shown while a refinement is in flight.
 *
 * Differences from `BorderedLoader` that matter for feel: the elapsed time
 * updates on the same tick as the spinner, and the hint line stays static, so
 * the widget never re-lays-out under the cursor while the model works.
 */
export class RefineLoader extends Container {
  private readonly ui: TUI;
  private readonly theme: Theme;
  private readonly baseLabel: string;
  private readonly statusText: Text;
  private readonly startedAt = Date.now();

  private frame = 0;
  private timer: ReturnType<typeof setInterval> | null = null;
  private abortedByUser = false;

  /** Called when the user presses Escape. */
  onAbort?: () => void;

  private readonly abortController = new AbortController();

  constructor(ui: TUI, theme: Theme, label: string) {
    super();
    this.ui = ui;
    this.theme = theme;
    this.baseLabel = label;

    const border = (s: string) => theme.fg("border", s);
    this.statusText = new Text("", 1, 0);

    this.addChild(new DynamicBorder(border));
    this.addChild(new Spacer(1));
    this.addChild(this.statusText);
    this.addChild(new Spacer(1));
    this.addChild(new Text(theme.fg("muted", "Esc cancels"), 1, 0));
    this.addChild(new Spacer(1));
    this.addChild(new DynamicBorder(border));

    this.tick();
    this.timer = setInterval(() => this.tick(), FRAME_MS);
  }

  get signal(): AbortSignal {
    return this.abortController.signal;
  }

  /** Whether the user cancelled the refinement. */
  get aborted(): boolean {
    return this.abortedByUser;
  }

  handleInput(data: string): void {
    const isEscape = data === "\u001b" || data === "\u0003";
    if (!isEscape) return;
    if (this.abortedByUser) return;
    this.abortedByUser = true;
    this.abortController.abort();
    this.onAbort?.();
  }

  dispose(): void {
    this.stop();
  }

  private stop(): void {
    if (this.timer !== null) {
      clearInterval(this.timer);
      this.timer = null;
    }
  }

  private tick(): void {
    const spinner = this.theme.fg("accent", FRAMES[this.frame % FRAMES.length]);
    this.frame += 1;

    const elapsed = Date.now() - this.startedAt;
    const seconds = `${(elapsed / 1000).toFixed(1)}s`;
    const suffix = elapsed >= SLOW_AFTER_MS ? " \u00b7 still working" : "";

    this.statusText.setText(
      `${spinner} ${this.theme.fg("text", this.baseLabel)} ${this.theme.fg("muted", `${seconds}${suffix}`)}`,
    );
    this.ui.requestRender();
  }
}
