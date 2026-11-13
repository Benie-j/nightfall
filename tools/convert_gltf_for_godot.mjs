import fs from 'node:fs/promises';
import path from 'node:path';
import { NodeIO } from '@gltf-transform/core';
import {
  EXTMeshoptCompression,
  KHRMeshQuantization
} from '@gltf-transform/extensions';
import { dequantize } from '@gltf-transform/functions';
import { MeshoptDecoder } from 'meshoptimizer';

const input = process.argv[2];

if (!input) {
  console.error('Fichier GLB manquant.');
  process.exit(2);
}

const source = path.resolve(input);
const temporary = source + '.godot-compatible.tmp.glb';

const io = new NodeIO()
  .registerExtensions([
    EXTMeshoptCompression,
    KHRMeshQuantization
  ])
  .registerDependencies({
    'meshopt.decoder': MeshoptDecoder
  });

try {
  await MeshoptDecoder.ready;

  const document = await io.read(source);

  // Décompresse les données Meshopt à la lecture,
  // puis restaure les attributs glTF standards.
  await document.transform(dequantize());

  for (const extension of document.getRoot().listExtensionsUsed()) {
    if (
      extension.extensionName === 'EXT_meshopt_compression' ||
      extension.extensionName === 'KHR_mesh_quantization'
    ) {
      extension.dispose();
    }
  }

  const remaining = document.getRoot()
    .listExtensionsUsed()
    .map(extension => extension.extensionName);

  if (
    remaining.includes('EXT_meshopt_compression') ||
    remaining.includes('KHR_mesh_quantization')
  ) {
    throw new Error(
      'Extensions incompatibles restantes : ' + remaining.join(', ')
    );
  }

  await io.write(temporary, document);

  const stat = await fs.stat(temporary);
  if (stat.size < 20) {
    throw new Error('Fichier GLB vide ou incomplet.');
  }

  await fs.rename(temporary, source);

  console.log(
    'GLB compatible : ' + input + ' (' + stat.size + ' octets)'
  );
} catch (error) {
  await fs.rm(temporary, { force: true });
  console.error('ÉCHEC CONVERSION :', input, error);
  process.exit(1);
}
