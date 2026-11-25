# Instala los paquetes de Wally y genera los tipos para Luau.
# Uso: .\install-packages.ps1
wally install
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

rojo sourcemap default.project.json --output sourcemap.json
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

wally-package-types --sourcemap sourcemap.json Packages/ ServerPackages/
exit $LASTEXITCODE
