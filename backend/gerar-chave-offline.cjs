// Execute na pasta backend: node gerar-chave-offline.cjs
// Gera um par Ed25519; guarde APENAS a chave privada no servidor.
const { generateKeyPairSync } = require('node:crypto');
const { privateKey, publicKey } = generateKeyPairSync('ed25519');
console.log('OFFLINE_SIGNING_PRIVATE_KEY_B64=' + privateKey.export({
  format: 'der', type: 'pkcs8'
}).toString('base64'));
console.log('OFFLINE_SIGNING_PUBLIC_KEY_B64=' + publicKey.export({
  format: 'der', type: 'spki'
}).toString('base64'));
console.log('Guarde a chave privada em segredo. A pública será incorporada ao Flutter.');
