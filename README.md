# Teacher Flávio — Atividades de Inglês

Repositório de páginas HTML estáticas para atividades de inglês do Teacher Flávio. O projeto reúne quizzes de gramática e exercícios interativos de ordenar palavras para formar frases em inglês.

O site foi pensado para uso por alunos em celular, com interface responsiva, navegação simples e coleta de desempenho.

## Estrutura principal

### Página inicial

- `index.html`

Página inicial do site. Atualmente contém apenas dois cards principais:

1. `QUIZZES` — redireciona para `quizzes.html`.
2. `ORDENAR FRASES` — redireciona para `exercicios_ordenar_frases.html`.

### Página de quizzes

- `quizzes.html`

Página com os cards dos quizzes disponíveis.

Quizzes atuais:

- `in_on_at.html` — quiz sobre as preposições `in`, `on` e `at`.
- `there_to_be.html` — quiz sobre `there is`, `there are` e formas relacionadas.
- `this_that_these_those.html` — quiz sobre demonstrativos.
- `simple_present.html` — quiz sobre Simple Present.
- `simple_past.html` — quiz sobre Simple Past.

### Página de exercícios de ordenar frases

- `exercicios_ordenar_frases.html`

Página com os cards dos exercícios em que o aluno deve organizar palavras para formar frases.

Exercício atual:

- `ordenar_simple_present.html` — exercício com 10 frases de nível A1 em Simple Present. O aluno arrasta as palavras com o dedo para colocá-las na ordem correta.

## Funcionalidades implementadas

### 1. Coleta de dados dos alunos

Antes de responder aos quizzes e ao exercício de ordenar frases, o aluno informa:

- nome;
- e-mail;
- autorização para registro do desempenho.

Esses dados são usados para associar cada resultado ao respectivo aluno.

### 2. Registro de desempenho

O sistema registra:

- data e hora;
- nome do aluno;
- e-mail do aluno;
- nome da atividade;
- quantidade de acertos;
- total de questões/frases;
- percentual de desempenho;
- identificador único do registro.

### 3. Integração com Google Sheets

Os resultados são enviados para uma planilha do Google Sheets por meio de um endpoint do Google Apps Script.

A URL do endpoint está configurada nas páginas das atividades por meio da variável:

```html
<script>
  window.QUIZ_RESULTS_ENDPOINT = "URL_DO_APPS_SCRIPT";
</script>
```

O envio é feito via `fetch` com `mode: "no-cors"`. Por isso, o navegador envia os dados, mas não confirma a resposta do Google Sheets. A validação real deve ser feita conferindo se uma nova linha apareceu na planilha.

### 4. Armazenamento local

Além do envio para a planilha, os resultados também são salvos no `localStorage` do navegador.

A página `resultados.html` permite consultar e exportar os registros salvos localmente em CSV. Essa página existe no repositório, mas não está mais exibida como card na página inicial.

### 5. Botão para avisar o professor

Ao final dos quizzes e dos exercícios de ordenar frases, aparece uma mensagem:

> Agora que você finalizou este quiz, avise o professor

Abaixo da mensagem, há o botão:

> AVISE O PROFESSOR

O botão abre o WhatsApp no link:

```text
https://wa.me/5534998349756
```

Esse comportamento é controlado pelo arquivo:

- `notify_teacher.js`

### 6. Motor compartilhado dos quizzes

Os quizzes usam um mecanismo comum no arquivo:

- `quiz_core.js`

Esse arquivo controla:

- formulário de identificação do aluno;
- validação de nome, e-mail e autorização;
- lógica de perguntas;
- pontuação;
- tela final;
- gravação local;
- envio dos dados para o Google Sheets;
- exportação CSV.

### 7. Rastreamento dos exercícios de ordenar palavras

O exercício `ordenar_simple_present.html` usa também:

- `word_order_tracking.js`

Esse script exibe o formulário de identificação do aluno, detecta a conclusão do exercício e envia o desempenho para a mesma planilha usada pelos quizzes.

## Arquivos importantes

| Arquivo | Função |
|---|---|
| `index.html` | Página inicial com dois cards principais. |
| `quizzes.html` | Lista de quizzes de gramática. |
| `exercicios_ordenar_frases.html` | Lista de exercícios de ordenar frases. |
| `quiz_core.js` | Motor compartilhado dos quizzes e funções de registro de resultados. |
| `word_order_tracking.js` | Coleta e registro de resultados dos exercícios de ordenar frases. |
| `notify_teacher.js` | Insere o botão de aviso ao professor ao final das atividades. |
| `resultados.html` | Consulta local e exportação CSV dos resultados salvos no navegador. |
| `ordenar_simple_present.html` | Exercício interativo de ordenar frases no Simple Present. |

## Como adicionar um novo quiz

1. Crie um novo arquivo `.html` para o quiz.
2. Inclua React, ReactDOM, `quiz_core.js` e, se quiser o botão do WhatsApp, `notify_teacher.js`.
3. Configure `window.QUIZ_RESULTS_ENDPOINT` antes de carregar `quiz_core.js`.
4. Use `QuizCore.renderQuiz({...})` com título, subtítulo opcional e lista de perguntas.
5. Adicione um card em `quizzes.html` apontando para o novo arquivo.

Exemplo simplificado:

```html
<script>
  window.QUIZ_RESULTS_ENDPOINT = "URL_DO_APPS_SCRIPT";
</script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/react/18.2.0/umd/react.production.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/react-dom/18.2.0/umd/react-dom.production.min.js"></script>
<script src="quiz_core.js"></script>
<script src="notify_teacher.js"></script>

<script>
  QuizCore.renderQuiz({
    title: "Novo Quiz",
    subtitle: "Escolha a alternativa correta",
    questions: [
      {
        question: "She ___ English.",
        options: ["speak", "speaks", "speaking", "spoke"],
        answer: "speaks",
        explanation: "Com she/he/it, usamos -s no Simple Present."
      }
    ]
  });
</script>
```

## Como adicionar um novo exercício de ordenar frases

1. Crie uma nova página baseada em `ordenar_simple_present.html`.
2. Altere o título, as frases e as traduções.
3. Mantenha `quiz_core.js`, `word_order_tracking.js` e `notify_teacher.js` se desejar coleta de dados, envio para Google Sheets e botão do WhatsApp.
4. Adicione um card em `exercicios_ordenar_frases.html`.

## Observações técnicas

- O projeto é estático e pode rodar em GitHub Pages.
- Não há backend próprio no repositório.
- O Google Sheets recebe os dados por meio de Google Apps Script.
- Dados pessoais são coletados: nome e e-mail. O formulário inclui autorização do aluno antes do registro.
- Para produção mais robusta, o ideal é migrar o registro de dados para um backend com controle de autenticação, logs e política formal de privacidade.

## Público-alvo

Alunos de inglês do Teacher Flávio, especialmente em atividades rápidas de revisão gramatical, prática de estrutura frasal e acompanhamento de desempenho.