// Shared fix-ups for inlined Luau harnesses that run from an OS temp folder.
import { readFileSync } from 'node:fs';
import { relative } from 'node:path';
import { fileURLToPath } from 'node:url';

const sharedFolder = fileURLToPath(new URL('../src/shared', import.meta.url));
// Admin.luau has no dependencies, so the real allow-list is inlined: admin-gated
// checks keep working and every other test player stays a non-admin.
const admin = '(function()\n' + readFileSync(new URL('../src/shared/Admin.luau', import.meta.url), 'utf8').replace(/\r\n/g, '\n') + '\nend)()';

// AnglerData lazily requires "../shared/X" outside Studio; point that at the
// repository from the temp folder. Services now require ReplicatedStorage.Shared.Admin,
// which the harness dependency maps don't provide.
export function patchHarnessRequires(program, folder) {
  const sharedPath = relative(folder, sharedFolder).replace(/\\/g, '/');
  return program
    .replaceAll('require("../shared/', 'require("' + sharedPath + '/')
    .replaceAll('require(ReplicatedStorage.Shared.Admin)', () => admin)
    .replaceAll('require(game:GetService("ReplicatedStorage").Shared.Admin)', () => admin);
}
