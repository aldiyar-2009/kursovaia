import * as materialsService from '../services/materials.service.js';
import { asyncHandler } from '../utils/http-error.js';

export const list = asyncHandler(async (req, res) => {
  const materials = await materialsService.listMaterials(req.user, req.query);
  res.json({ materials });
});

export const upload = asyncHandler(async (req, res) => {
  const material = await materialsService.createMaterial(req.user, req.file, req.body);
  res.status(201).json({ material });
});

export const remove = asyncHandler(async (req, res) => {
  const result = await materialsService.deleteMaterial(req.user, req.params.id);
  res.json(result);
});
