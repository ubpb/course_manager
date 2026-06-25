import * as sass from "sass";
import { dirname } from "path";

export default {
  name: "sass",
  setup(build) {
    build.onLoad({ filter: /\.scss$/ }, ({ path }) => {
      const result = sass.compile(path, {
        loadPaths: ["node_modules"],
        sourceMap: false,
      });
      return { contents: result.css, loader: "css", resolveDir: dirname(path) };
    });
  },
};
