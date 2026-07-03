# SuaveScroll

**Rolagem suave e fluida para a rodinha do mouse no macOS — grátis e de código aberto.**

O SuaveScroll intercepta os "pulos" da rodinha de um mouse comum e os substitui
por um deslize fluido, pixel a pixel — a mesma sensação de um trackpad, em
todos os aplicativos, no sistema inteiro. Uma alternativa gratuita a
ferramentas pagas como o SmoothScroll.

- 🖱️ Suaviza só a rodinha do mouse — trackpad e Magic Mouse nunca são tocados
- 🤝 Funciona junto com drivers de fabricante (Logitech Options+, etc.)
- ⚡ Animação a 120 Hz com desaceleração exponencial (aceleração natural + deslize)
- 🎛️ Distância e duração do deslize ajustáveis
- 🔄 Opção de inverter a direção da rolagem
- 🚫 Lista de aplicativos excluídos (jogos, acesso remoto, etc.)
- ⌨️ Shift + rodinha rola na horizontal; zoom com Ctrl + rodinha continua funcionando
- 🪶 App minúsculo na barra de menu, sem ícone no Dock
- 🔁 Inicia com o Mac automaticamente e sobrevive ao repouso (religa o
  interceptador se o sistema o desativar ao acordar)
- 🔔 Avisa no menu quando uma versão nova é publicada

## Instalação (usuários)

1. Baixe o `SuaveScroll.dmg` na [página de Releases](https://github.com/xenerrer/SuaveScroll/releases)
2. Abra o DMG e **arraste o SuaveScroll para a pasta Applications**
3. Abra o SuaveScroll. Como o app não é notarizado pela Apple (certificado de
   desenvolvedor custa US$ 99/ano), o macOS vai bloquear a primeira abertura —
   vá em **Ajustes do Sistema → Privacidade e Segurança**, role até o final e
   clique em **"Abrir Mesmo Assim"**
4. Conceda o acesso de **Acessibilidade** quando o app pedir (Ajustes do
   Sistema → Privacidade e Segurança → Acessibilidade → ative o SuaveScroll)

Pronto — a rolagem suave começa imediatamente. O ícone de mouse na barra de
menu dá acesso às configurações.

> Alternativa ao passo 3, no Terminal:
> `xattr -cr /Applications/SuaveScroll.app`

## Atualizações

O SuaveScroll verifica a cada 6 horas se existe versão nova no GitHub. Quando
houver, aparece **"⬆️ Atualizar para a versão X"** no menu do ícone do mouse —
clique, baixe o novo DMG e arraste o app para Applications de novo,
substituindo o antigo. Suas configurações são preservadas.

> Como a assinatura do app muda entre versões, o macOS pode exigir repetir o
> passo do "Abrir Mesmo Assim" e reativar o interruptor de Acessibilidade
> após atualizar. Atualização com um clique (Sparkle) está no roadmap.

## Requisitos

- macOS 13 (Ventura) ou mais recente
- Para compilar do código-fonte: Xcode Command Line Tools (`xcode-select --install`)

## Compilar do código-fonte

```sh
make run   # compila, monta dist/SuaveScroll.app e abre
make dmg   # gera o instalador dist/SuaveScroll.dmg
```

> **Nota para desenvolvedores:** o bundle usa assinatura ad-hoc, então a
> assinatura muda a cada rebuild e o macOS pode "esquecer" a permissão de
> Acessibilidade. Se a rolagem parar de funcionar depois de recompilar, remova
> o SuaveScroll da lista de Acessibilidade (botão −) e adicione de novo, ou
> desative e reative o interruptor.

## Como funciona

1. Um `CGEventTap` (Quartz Event Services) escuta todos os eventos `scrollWheel`.
2. Eventos com fases de gesto (trackpad / Magic Mouse), e os eventos que o
   próprio SuaveScroll sintetiza (identificados por um marcador na origem),
   passam intactos.
3. Eventos de rodinha sem fase — cliques discretos, ou os eventos contínuos em
   pixels que drivers como o Logi Options+ emitem — são engolidos e convertidos
   em uma distância em pixels (`cliques × distância`, respeitando a aceleração).
4. Um animador a 120 Hz emite a distância restante como eventos contínuos de
   rolagem em pixels com desaceleração exponencial: a página desliza em vez de
   pular.

## Configurações

| Configuração | Padrão | Significado |
| --- | --- | --- |
| Distância por clique | 60 px | Pixels rolados por clique da rodinha |
| Duração do deslize | 240 ms | Tempo até o deslize assentar |
| Inverter direção | desligado | Inverte o sentido da rolagem |
| Aplicativos excluídos | — | Bundle IDs onde a rolagem fica crua |

## Roadmap

- [ ] Atualização automática com um clique (Sparkle) e assinatura estável
- [ ] Distribuição via Homebrew (`brew install --cask`)
- [ ] Fases de momentum/gesto nos eventos sintetizados (efeito elástico em alguns apps)
- [ ] Configurações por dispositivo
- [ ] Suavização da rolagem por teclado (setas / espaço)
- [ ] Mais idiomas na interface

## Créditos

Criado por **Lucas Schoenherr** ([@lucasschoenherr](https://github.com/xenerrer)).
Se este projeto te ajudou, ⭐ deixe uma estrela no repositório e **me siga nas
redes sociais: @lucasschoenherr** 😉

Inspirado no [SmoothScroll](https://www.smoothscroll.net) (pago) e no
[Mos](https://github.com/Caldis/Mos) (código aberto). Escrito do zero em Swift.

## Licença

[MIT](LICENSE) — © 2026 Lucas Schoenherr

---

## 🇺🇸 English

SuaveScroll gives mouse wheels buttery smooth, trackpad-like scrolling
system-wide on macOS — a free, open-source alternative to paid tools like
SmoothScroll. Trackpads and Magic Mouse are never affected, and it works
alongside vendor drivers such as Logitech Options+.

**Install:** download `SuaveScroll.dmg` from
[Releases](https://github.com/xenerrer/SuaveScroll/releases), drag the app to
Applications, allow it under System Settings → Privacy & Security ("Open
Anyway" — the app is not notarized), then grant Accessibility access.
**Build from source:** `make run` (requires Xcode Command Line Tools).

The UI is currently in Brazilian Portuguese; localization is on the roadmap.
Created by **Lucas Schoenherr** ([@lucasschoenherr](https://github.com/xenerrer)) —
follow me on social media: **@lucasschoenherr**.
