import {readFileSync,writeFileSync} from 'node:fs';
import {seasonalFishIds} from '../scripts/seasonal-fish.mjs';
const scientific = [
'Salvelinus fontinalis','Salmo trutta','Salvelinus namaycush','Salvelinus alpinus','Salvelinus malma',
'Prosopium williamsoni','Thymallus arcticus','Lota lota','Coregonus autumnalis','Coregonus clupeaformis',
'Macquaria ambigua','Pomoxis annularis','Pomoxis nigromaculatus','Lepomis gibbosus','Rutilus rutilus',
'Scardinius erythrophthalmus','Tinca tinca','Ctenopharyngodon idella','Cyprinus carpio','Carassius carassius',
'Esox niger','Esox masquinongy','Amia calva','Lepisosteus osseus','Atractosteus spatula',
'Paracanthurus hepatus','Acanthurus leucosternon','Zebrasoma flavescens','Zanclus cornutus','Chelmon rostratus',
'Chaetodon lunula','Pomacanthus imperator','Holacanthus ciliaris','Centropyge loricula','Pterois volitans',
'Synchiropus splendidus','Gramma loreto','Nemateleotris magnifica','Pterapogon kauderni','Abudefduf saxatilis',
'Rhinecanthus aculeatus','Balistoides conspicillum','Naso unicornis','Cheilinus undulatus','Lachnolaimus maximus',
'Sphyraena barracuda','Acanthocybium solandri','Balistes vetula','Rachycentron canadum','Albula vulpes',
];
if(scientific.length!==50 || seasonalFishIds.length!==50) throw Error('Expected fifty identities');
const clearer={Unicornfish:'Bluespine Unicornfish', Lionfish:'Red Lionfish', Barracuda:'Great Barracuda'};
let doc=readFileSync('docs/SEASONAL_FISH_EXPANSION.md','utf8');
for(let i=0;i<50;i++) {
 const path='src/shared/Fish/'+seasonalFishIds[i]+'.luau';
 let src=readFileSync(path,'utf8');
 const original=src.match(/\tName = "([^"]+)",/)[1];
 const name=clearer[seasonalFishIds[i]] || original;
 src=src.replace(/\tName = "[^"]+",/,()=>`\tName = "${name}",\n\tScientificName = "${scientific[i]}",`);
 if(seasonalFishIds[i]==='MirrorCarp') src=src.replace('return {','-- Mirror carp are a real scale-pattern variety of common carp, not a separate species.\nreturn {');
 writeFileSync(path,src);
 doc=doc.replace('| '+original+' |', '| '+name+' | *'+scientific[i]+'* |');
}
doc=doc.replace('| Species | Areas | Seasons | Additional requirements |','| Fish | Scientific name | Areas | Seasons | Additional requirements |').replace('|---|---|---|---|','|---|---|---|---|---|');
doc=doc.replace('## Registration and 3D meshes',`## Real fish identities

All 50 additions represent living fish species or real varieties. Each module records its ScientificName, which is preserved in AnglerCatalog. Mirror Carp is a scale-pattern variety of common carp (Cyprinus carpio), so this is 50 fish entries rather than 50 distinct biological species. Generic labels are pinned to specific species: Red Lionfish (Pterois volitans), Great Barracuda (Sphyraena barracuda), and Bluespine Unicornfish (Naso unicornis). IDs remain stable for saved catches.

Reference examples: [Alaska fish species](https://www.adfg.alaska.gov/index.cfm?adfg=animals.listfish), [Australian Museum blue tang](https://australian.museum/learn/animals/fishes/blue-tang-paracanthurus-hepatus/), [Australian Museum unicornfish](https://lifg.australian.museum/Group.html?groupId=4h45V1Tl&hierarchyId=PVWrQCLG), [Florida Museum species profiles](https://www.floridamuseum.ufl.edu/discover-fish/species-profiles/), [mirror carp identification](https://www.mdb.fish/fish-fact-sheets/carp), [mandarinfish observation](https://lkcnhm.nus.edu.sg/wp-content/uploads/sites/10/2022/05/NIS-2022-0054.pdf).

The calendar, game regions, weights, rarity and prices are gameplay settings; they do not describe natural geographic ranges, migration calendars or biological records.

## Registration and 3D meshes`);
doc=doc.replaceAll('Lionfish and Mandarinfish','Red Lionfish and Mandarinfish');
writeFileSync('docs/SEASONAL_FISH_EXPANSION.md',doc);
console.log('Recorded fifty real fish identities; clarified three display names.');
