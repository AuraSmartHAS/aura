const fs = require('fs');
const path = require('path');

/**
 * `google-services.json` do app RN: pacote br.com.fiap.aura.rn no projeto Firebase aura-84408
 * (configuração pública do cliente, como a do app Flutter — não é a conta de serviço). Com ele, o
 * dev build Android recebe push; sem ele (web da demo, clone sem o arquivo), o app sobe igual e o
 * push fica desligado — o plugin do Firebase falharia com o caminho apontando para o nada.
 */
module.exports = ({ config }) => {
  const googleServices = path.join(__dirname, 'google-services.json');
  if (!fs.existsSync(googleServices)) return config;
  return {
    ...config,
    android: { ...config.android, googleServicesFile: './google-services.json' },
  };
};
