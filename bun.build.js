import sassPlugin from "./bun.plugin.sass.js";
import { watch } from "fs";

const isWatch = process.argv.includes("--watch");

async function build() {
  const result = await Bun.build({
    entrypoints: ["./app/assets/src/application.js"],
    outdir: "./app/assets/builds",
    target: "browser",
    format: "iife",
    sourcemap: "linked",
    naming: {
      entry: "[name].[ext]",
      asset: "[name]-[hash].[ext]",
    },
    plugins: [sassPlugin],
    minify: process.env.NODE_ENV === "production",
  });

  if (!result.success) {
    for (const log of result.logs) console.error(log);
    if (!isWatch) process.exit(1);
    return false;
  }

  console.log("Build completed successfully.");
  return true;
}

await build();

if (isWatch) {
  console.log("Watching for changes in app/assets/src/...");

  let timeout;
  watch("./app/assets/src", { recursive: true }, (_event, _filename) => {
    clearTimeout(timeout);
    timeout = setTimeout(async () => {
      console.log("Rebuilding...");
      await build();
    }, 100);
  });
}
