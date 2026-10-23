const importModel = require('./import-tinkercad.cjs');
const check = process.argv.includes('--check');
importModel({assetDir:'shop-desk',moduleName:'ShopDeskGeometry',sourceName:'Ingenious Lappi',expected:{vertices:48,objects:6,faces:72,groups:6},check});
importModel({assetDir:'cash-register',moduleName:'CashRegisterGeometry',sourceName:'Cash Register',expected:{vertices:523,objects:1,faces:1058,groups:4},rectangles:true,check});
