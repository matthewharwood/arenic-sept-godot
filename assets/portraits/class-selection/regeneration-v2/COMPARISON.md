# Class hero comparison

The regenerated v2 portraits are now the selected game art for all eight hero identities. **Previous** links to archived v1 originals in `before/`; **Current** links to the approved v2 images copied into the game's existing runtime paths.

[active-portraits.json](../active-portraits.json) records the current runtime/source/archive mapping, hashes, and activation time.

The v2 portraits use the current built-in image tool, which does not expose its model identifier; this comparison does not establish a model upgrade. Each previous portrait served as an identity and style reference for a fresh illustration. Prompts requested refinements to anatomy, expression, and linework, so these are creative variants rather than a controlled model benchmark.

Open [the interactive comparison](compare.html) to switch between heroes at equal display size. The optional **Sunburst backdrop** is a separate preview treatment; white mode shows the original image colors. It is not baked into the PNGs or connected to the game.

| Hero | Previous: archived v1 | Current: active v2 |
| --- | --- | --- |
| Hunter — Dean | ![Hunter Dean previous v1](before/hunter.png) | ![Hunter Dean current v2](hunter-v2.png) |
| Bard — Marcus | ![Bard Marcus previous v1](before/bard.png) | ![Bard Marcus current v2](bard-v2.png) |
| Merchant — Calvin | ![Merchant Calvin previous v1](before/merchant.png) | ![Merchant Calvin current v2](merchant-v2.png) |
| Warrior — King | ![Warrior King previous v1](before/warrior.png) | ![Warrior King current v2](warrior-v2.png) |
| Cardinal — Pius | ![Cardinal Pius previous v1](before/cardinal.png) | ![Cardinal Pius current v2](cardinal-v2.png) |
| Alchemist — Giuseppe | ![Alchemist Giuseppe previous v1](before/alchemist.png) | ![Alchemist Giuseppe current v2](alchemist-v2.png) |
| Forager — Daisy | ![Forager Daisy previous v1](before/forager.png) | ![Forager Daisy current v2](forager-v2.png) |
| Thief — Ginger | ![Thief Ginger previous v1](before/thief.png) | ![Thief Ginger current v2](thief-v2.png) |

Compare identity, expression, silhouette, gear, linework, palette, and full-body framing. These are source-image comparisons: the current runtime PNGs have near-white backing that Godot removes with a shader, so the table does not show their in-game cutouts.

The [historical v1 generation manifest](../generation-manifest.json) retains exact earlier prompts, reference-image paths, generated source paths, and hashes for the archived originals. Its recorded runtime paths describe the original generation, before v2 replaced those files.

The v2 prompts and source records are in [Hunter, Bard, Merchant](batch-hbm.json), [Warrior, Cardinal, Alchemist](batch-wca.json), and [Forager, Thief](batch-ft.json). The [v2 comparison verification](verification.json) records image hashes and review results before activation. All v2 images preserve the generated files byte-for-byte.
