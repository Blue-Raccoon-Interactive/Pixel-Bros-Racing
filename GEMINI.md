# Regras do Projeto (Godot)

- **Linguagem:** GDScript (Godot 4.7).
- **Estrutura de Arquivos:**
  - Scripts: `res://scripts/`
  - Cenas: `res://scenes/`
- **Manipulação de Cenas:**
  - Alterar cenas **exclusivamente** através das ferramentas integradas do Godot (`godot-ai` MCP).
  - **Nunca** editar arquivos `.tscn` diretamente como texto.
- **Sincronização e Inspeção Prévia:**
  - O usuário também realiza edições manuais no editor do Godot.
  - **Sempre** inspecione e leia o estado atual da cena (usando ferramentas como `editor_state`, `scene_get_hierarchy` ou recursos equivalentes) antes de realizar qualquer modificação.
- **Encerramento de Tarefas:**
  - Ao finalizar cada tarefa, salve a cena aberta (`scene_save`).
  - Forneça um resumo claro e detalhado de todas as alterações realizadas.
