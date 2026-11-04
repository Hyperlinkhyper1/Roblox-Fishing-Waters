import {readFile,writeFile,mkdtemp,rm} from 'node:fs/promises';
import {spawnSync} from 'node:child_process';
import {tmpdir} from 'node:os';
import {dirname,join,resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
const root=resolve(dirname(fileURLToPath(import.meta.url)),'..');
const [source,fixture]=await Promise.all(['src/client/BuildPaintQueue.luau','scripts/build-paint-queue.luau'].map(path=>readFile(join(root,path),'utf8')));
const directory=await mkdtemp(join(tmpdir(),'build-paint-queue-'));
try {
 const path=join(directory,'paint.luau');await writeFile(path,fixture.replace('-- BUILD_PAINT_QUEUE --',source));
 const result=spawnSync(process.env.LUTE||'lute',['run',path],{cwd:root,encoding:'utf8',timeout:30000});
 if(result.stdout)process.stdout.write(result.stdout);if(result.stderr)process.stderr.write(result.stderr);
 if(result.error)throw result.error;if(result.status!==0)throw new Error('Build paint queue checks failed ('+result.status+')');
} finally {await rm(directory,{recursive:true,force:true});}
