# inow jbrake

Réplica do app INOW (bikes elétricas) em Flutter, para testes locais.
Protocolo extraído do APK Android oficial (`com.qmwheelbike.inow` v1.1.3).

## Rodar

```bash
flutter pub get
flutter test
flutter run            # com o iPhone/Android conectado
```

No iPhone: ative o Modo de Desenvolvedor (Ajustes → Privacidade e Segurança)
e, na primeira vez, abra `ios/Runner.xcworkspace` no Xcode → Runner →
Signing & Capabilities → marque o seu time para gerar o perfil.

## Protocolo Bluetooth (resumo)

| Perfil   | Serviço                                | Escrita   | Notificação |
|----------|----------------------------------------|-----------|-------------|
| standard | `12ff69a0-73ae-11ee-b962-0002a5d5c51b` | `…69a1`   | `…69a4`     |
| ln       | `d3b85480-7d79-464c-a646-0002a5d5c51b` | `…5481`   | `…5484`     |
| reel     | `5e399c40-a7f1-11eb-bcbc-0002a5d5c51b` | `…9c41`   | `…9c44`     |

Conexão:
1. Liga notificações; 500 ms depois envia `+VER?`.
2. Autenticação mútua: `+VER=…` → `+PM?` → `+PM>nonce` → `+PM<hash` →
   `+PM=OK` → `+PA<nonce` → `+PA>hash` (ver `bonding_hash.dart`).
3. Senha: `CODE=000000` → `CODE_OK` / `CODE_NG`.
4. `GETDEVID` → modelo (ex.: `imoogoo-inow05`).

Comandos (texto): `+MODE=n`, `+LOCK=0/1`, `+UNIT`, `+CRZE`, `+BRAKE`,
`+HANDRAIL`, `+ZSST`, `+LUMA`, `+SPDLMT`… Consulta: `+CHAVE=?`.

Telemetria: pacotes binários, 4 formatos possíveis (`telemetry_parser.dart`).
A tela **Console** mostra qual formato a sua bike usa.

## Estrutura

```
lib/
  core/        constantes, tema, rotas
  features/bike/
    data/protocol/     UUIDs, hash, handshake, comandos, telemetria
    data/datasources/  Bluetooth (flutter_blue_plus) e Hive (senhas)
    domain/entities/   BikeState
    presentation/      providers (Riverpod) e telas
  features/fleet/      aba "Bicicletas": operação em lote (marcha mínima)
    domain/gateways/   BikeFleetGateway (contrato)
    data/gateways/     BleBikeFleetGateway (Bluetooth real) e
                       MockBikeFleetGateway (simulado, usado nos testes)
  features/app_settings/  Configurações do app (Hive, caixa `app_settings`)
```

**Operação "Bicicletas"** — busca bikes INOW por perto (sem nenhuma, continua
até o tempo máximo; com alguma, para 3 s depois da última nova) e, uma por vez:
conecta → autenticação + senha padrão → `GETDEVID`/`+MDMX`/`+LOCK`/`HLGT` →
`+MODE=n` → confere com `+MODE=?` → se respondeu ao `+LOCK=?`, `+LOCK=1` e
confere → desconecta. O tráfego aparece no Console.

- **Iniciar operação**: uma passada pela lista.
- **Iniciar operação contínua**: repete busca + ações até "Parar". Bikes já
  concluídas não são acionadas de novo; as que falharam, sim.
- **Parar**: interrompe na hora (não espera o tempo limite) e desconecta a
  bike ativa em segundo plano. **Iniciar** sempre limpa a lista e busca de novo.
- **Bloquear** (no cartão da bike): a bike continua listada, mas a operação
  pula. Lista salva no aparelho (caixa `fleet_blocklist`); remova pelo cartão
  ou em Configurações → Bicicletas bloqueadas.
- **Configurações → Modo simulação**: bikes fictícias no lugar do Bluetooth.
