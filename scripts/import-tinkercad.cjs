// Local OBJ/MTL conversion. Source faces remain in the bundle for transfer audits.
const fs = require("node:fs");
const path = require("node:path");
const crypto = require("node:crypto");
const subtract = (a, b) => a.map((v, i) => v - b[i]);
const add = (a, b) => a.map((v, i) => v + b[i]);
const multiply = (a, n) => a.map(v => v * n);
const dot = (a, b) => a.reduce((sum, v, i) => sum + v * b[i], 0);
const cross = (a, b) => [a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0]];
const magnitude = a => Math.hypot(...a);
const unit = a => multiply(a, 1 / magnitude(a));

function findBox(points) {
  const origin = points[0], edges = points.slice(1).map(p => subtract(p, origin));
  for (let i = 0; i < edges.length; i++) for (let j = i+1; j < edges.length; j++) for (let k = j+1; k < edges.length; k++) {
    const axes = [edges[i], edges[j], edges[k]], size = axes.map(magnitude), units = axes.map(unit);
    if (Math.abs(dot(units[0],units[1])) > 1e-5 || Math.abs(dot(units[1],units[2])) > 1e-5 || Math.abs(dot(units[0],units[2])) > 1e-5) continue;
    let matches = true;
    for (let mask = 0; mask < 8; mask++) {
      const corner = origin.map((v, axis) => v + axes.reduce((sum, edge, e) => sum + ((mask >> e) & 1) * edge[axis], 0));
      if (!points.some(p => magnitude(subtract(p, corner)) < 0.001)) { matches = false; break; }
    }
    if (matches) return {center: origin.map((v,a) => v + axes.reduce((sum,edge) => sum+edge[a]/2,0)), size, right:units[0], up:units[1]};
  }
}

function findRectangles(object, vertices) {
  const planes = new Map();
  object.faces.forEach((face, index) => {
    const [a,b,c] = face.map(i => vertices[i-1]);
    const normal = cross(subtract(b,a),subtract(c,a));
    if (magnitude(normal) < 1e-10) return;
    const n = unit(normal), d = dot(n,a);
    const key = n.map(v => v.toFixed(5)).join(',') + ':' + d.toFixed(3);
    if (!planes.has(key)) planes.set(key, []);
    planes.get(key).push({index, face, n, d, area:magnitude(normal)/2});
  });
  const rectangles = [];
  for (const entries of planes.values()) {
    // Split disconnected button tops and panels before checking rectangle coverage.
    const parents = entries.map((_,i) => i), shared = new Map();
    const find = i => parents[i] === i ? i : parents[i] = find(parents[i]);
    entries.forEach((entry,i) => entry.face.forEach(v => {
      const key = vertices[v-1].map(n => n.toFixed(6)).join(',');
      if (shared.has(key)) parents[find(i)] = find(shared.get(key));
      else shared.set(key,i);
    }));
    const components = new Map();
    entries.forEach((entry,i) => { const key = find(i); if (!components.has(key)) components.set(key,[]); components.get(key).push(entry); });
    for (const component of components.values()) {
      if (component.length < 2) continue;
      const points = [...new Set(component.flatMap(e => e.face))].map(i => vertices[i-1]);
      const {n,d} = component[0];
      if (points.some(p => Math.abs(dot(n,p)-d) > 0.0001)) continue;
      const area = component.reduce((sum,e) => sum+e.area,0), attempted = new Set();
      let rectangle;
      for (const entry of component) {
        for (let edge = 0; edge < 3; edge++) {
          const delta = subtract(vertices[entry.face[(edge+1)%3]-1], vertices[entry.face[edge]-1]);
          if (magnitude(delta) < 1e-6) continue;
          const right = unit(delta), up = unit(cross(n,right));
          const key = right.map(v => Math.abs(v).toFixed(5)).join(',');
          if (attempted.has(key)) continue;
          attempted.add(key);
          const xs = points.map(p => dot(p,right)), ys = points.map(p => dot(p,up));
          const x0 = Math.min(...xs), x1 = Math.max(...xs), y0 = Math.min(...ys), y1 = Math.max(...ys);
          if (Math.abs((x1-x0)*(y1-y0)-area) > Math.max(1e-5,area*1e-6)) continue;
          rectangle = {center:add(add(multiply(right,(x0+x1)/2),multiply(up,(y0+y1)/2)),multiply(n,d)), size:[x1-x0,y1-y0,0],right,up,faces:component.map(e => e.index+1)};
          break;
        }
        if (rectangle) break;
      }
      if (rectangle) rectangles.push(rectangle);
    }
  }
  return rectangles;
}

module.exports = function importModel({assetDir,moduleName,sourceName,expected,rectangles=false,check=false}) {
  const root = path.resolve(__dirname,'..'), folder = path.join(root,'assets/models',assetDir);
  const obj = fs.readFileSync(path.join(folder,'tinker.obj'),'utf8'), mtl = fs.readFileSync(path.join(folder,'obj.mtl'),'utf8');
  const materials = {}; let material;
  for (const line of mtl.split(/\r?\n/)) {
    const [kind,...values] = line.trim().split(/\s+/);
    if (kind === 'newmtl') material = values[0];
    if (kind === 'Kd') materials[material] = values.map(Number);
    if (kind === 'd' && Number(values[0]) !== 1) throw new Error('Handle source transparency explicitly');
  }
  const vertices = [], sourceObjects = []; let object, currentMaterial;
  for (const line of obj.split(/\r?\n/)) {
    const [kind,...values] = line.trim().split(/\s+/);
    if (kind === 'o') { object={name:values[0],groups:new Map()}; sourceObjects.push(object); }
    else if (kind === 'v') vertices.push(values.map(Number));
    else if (kind === 'usemtl') currentMaterial=values[0];
    else if (kind === 'f') {
      if (values.length !== 3) throw new Error('Expected triangulated OBJ');
      const face=values.map(v=>Number(v.split('/')[0]));
      if (!object || !materials[currentMaterial] || face.some(i=>!Number.isInteger(i)||i<1||i>vertices.length)) throw new Error('Invalid source face/material');
      if (!object.groups.has(currentMaterial)) object.groups.set(currentMaterial,[]);
      object.groups.get(currentMaterial).push(face);
    }
  }
  const objects = sourceObjects.flatMap(source => [...source.groups].map(([material,faces]) => ({name:source.name+(source.groups.size>1?'_'+material:''),sourceObject:source.name,color:materials[material],faces})));
  const counts = {vertices:vertices.length, objects:sourceObjects.length, faces:objects.reduce((sum,o)=>sum+o.faces.length,0), groups:objects.length};
  for (const [key,value] of Object.entries(expected)) if (counts[key] !== value) throw new Error(`${sourceName}: unexpected ${key}: ${counts[key]}`);
  let degenerateFaces=0;
  for (const object of objects) {
    const indices=[...new Set(object.faces.flat())];
    if (indices.length===8 && object.faces.length===12) object.box=findBox(indices.map(i=>vertices[i-1]));
    if (!object.box && rectangles) object.rectangles=findRectangles(object,vertices);
    for (const face of object.faces) { const [a,b,c]=face.map(i=>vertices[i-1]); if(magnitude(cross(subtract(b,a),subtract(c,a)))<1e-10)degenerateFaces++; }
  }
  const hash=crypto.createHash('sha256').update(obj).update(mtl).digest('hex');
  const vec = v => `Vector3.new(${v.map(n=>Number(n.toFixed(9))).join(', ')})`;
  const rows=[`-- Generated by scripts/import-tinkercad.cjs from ${sourceName}.zip.`, `-- SHA-256 (OBJ + MTL): ${hash}`, 'return {',`\tsourceHash = "${hash}",`,`\tsourceObjectCount = ${sourceObjects.length},`,`\tdegenerateFaceCount = ${degenerateFaces},`,`\tboundsMin = ${vec([0,1,2].map(a=>Math.min(...vertices.map(v=>v[a]))))},`,`\tboundsMax = ${vec([0,1,2].map(a=>Math.max(...vertices.map(v=>v[a]))))},`,'\tvertices = {',...vertices.map(v=>`\t\t${vec(v)},`),'\t},','\tobjects = {'];
  for (const object of objects) {
    rows.push('\t\t{',`\t\t\tname = "${object.name}",`,`\t\t\tsourceObject = "${object.sourceObject}",`,`\t\t\tcolor = Color3.new(${object.color.join(', ')}),`);
    const shape = (value,indent) => {
      for (const key of ['center','size','right','up']) rows.push(`${indent}${key} = ${vec(value[key])},`);
      if (value.faces) rows.push(`${indent}faces = { ${value.faces.join(', ')} },`);
    };
    if (object.box) { rows.push('\t\t\tbox = {'); shape(object.box,'\t\t\t\t'); rows.push('\t\t\t},'); }
    if (object.rectangles?.length) { rows.push('\t\t\trectangles = {'); for(const rect of object.rectangles){rows.push('\t\t\t\t{');shape(rect,'\t\t\t\t\t');rows.push('\t\t\t\t},');} rows.push('\t\t\t},'); }
    rows.push('\t\t\tfaces = {',...object.faces.map(f=>`\t\t\t\t{ ${f.join(', ')} },`),'\t\t\t},','\t\t},');
  }
  rows.push('\t},','}','');
  const target=path.join(root,'src/server/Map',moduleName+'.luau'), output=rows.join('\n');
  if(check){if(fs.readFileSync(target,'utf8').replace(/\r\n/g,'\n')!==output)throw new Error(`Regenerate ${moduleName} from its source`);}
  else fs.writeFileSync(target,output);
  console.log(`${sourceName}: ${JSON.stringify(counts)}, ${objects.filter(o=>o.box).length} cuboids, ${objects.reduce((n,o)=>n+(o.rectangles?.length||0),0)} rectangular surfaces, ${degenerateFaces} zero-area source faces retained as data.`);
};
