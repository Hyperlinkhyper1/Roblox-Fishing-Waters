// Shared.FishSpecies for node harnesses that bundle AnglerCatalog or FishModels
// as text: every src/shared/Fish module inlined into one Luau expression.
import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

export function fishSpeciesSource(root) {
  const dir = join(root, 'src', 'shared', 'Fish');
  const entries = readdirSync(dir)
    .filter((file) => file.endsWith('.luau'))
    .sort()
    .map((file) => {
      const source = readFileSync(join(dir, file), 'utf8').replace(/\r\n/g, '\n');
      return `species[${JSON.stringify(file.slice(0, -5))}] = (function()\n${source}\nend)()`;
    });
  return `(function()\nlocal species = {}\n${entries.join('\n')}\nreturn species\nend)()`;
}

// `source` with its `require(script.Parent.FishSpecies)` swapped for the inlined species.
export function inlineFishSpecies(source, root) {
  return source.replace('require(script.Parent.FishSpecies)', () => fishSpeciesSource(root));
}
