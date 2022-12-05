paa-browser-help(){
cat <<EOF

  Collection of snippets to cut and paste in the browser.
  Scrapes OpenAi chat session and turns it into a file
  via Jakub T. Janiewicz et. al:

  https://dev.to/jcubic/save-chatgpt-as-html-file-dhh

EOF
}

# Jakub's version
paa-bookmark-getChatGpt(){

#remove 'javascript:' and paste this in your console
cat <<'EOF'
javascript:( function()
{ 
  const a = document.createElement('a');
  a.href = URL.createObjectURL(
    new Blob(
      [document.querySelector(
        '[class^="ThreadLayout__NodeWrapper"]').innerHTML],
        {type: 'text/html'})
  );
    
  a.download = 'chatGPT.html';
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(a.href);
})()
EOF
}

paa-browser-getChatGpt-clean(){
cat <<'EOF'
javascript:(function() {
const a = document.createElement('a');
a.href = URL.createObjectURL(
new Blob(
  [
  document.querySelector(
  '[class^="ThreadLayout__NodeWrapper"]').
  innerHTML.replace(/<img[^>]*>/g, '').
  replace(/<button[^>]*>.*?<\/button>/g, '').
  replace(/<svg[^>]*>.*?<\/svg>/g, '')
  ],
  {type: 'text/html'})
);
a.download = 'chatGPT.html';
document.body.appendChild(a); a.click();
document.body.removeChild(a);
URL.revokeObjectURL(a.href); 
})()
EOF
}

paa-browser-getChatGpt-long(){
#via Enzi on dev.to
#remove 'javascript:' and paste this in your console
cat <<'EOF'
javascript:(function () {
  const a = document.createElement("a");
  a.href = URL.createObjectURL(
    new Blob(
      [
        `<!DOCTYPE html><html><head><style>
[class^="ConversationItem__ConversationItemWrapper-sc"]:nth-child(2n+1) {
    background: lightgray;
}
[class^="ConversationItem__ConversationItemWrapper-sc"]:nth-child(2n+2) {
    background: darkgray;
}

[class^="ConversationItem__ConversationItemWrapper-sc"] {
    padding: 10px;
    margin: 10px;
    border-radius: 5px;
}

[class^="CodeSnippet__CodeContainer-sc"] {
    background: #0D0D0D;
    padding: 10px;
    border-radius: 5px;
}

[class^="hljs"] {
    font-weight: !important;
}

[class^="hljs-comment"] {
    color: #DAD9D8 !important;
}
[class^="hljs-keyword"] {
    color: #4CA3D8 !important;
}
[class^="hljs-params"] {
    color: #ff6c87 !important;
}
[class^="hljs-variable language_"] {
    color: #E24B8A !important;
}
[class^="hljs-title function_"] {
    color: #F24554 !important;
}
[class^="hljs-string"] {
    color: #56FEC1 !important;
}
[class^="hljs-property"] {
    color: #FFFFFF !important;
}
[class^="hljs-built_in"] {
    color: #F3AC35 !important;
}
[class^="hljs-attribute"] {
    color: #60FED7 !important;
}
[class^="hljs-attr"] {
    color: #E24B8A !important;
}
[class^="hljs-regexp"] {
    color: #dad9d8 !important;
}
[class^="hljs-selector-attr"] {
    color: #E24B8A !important;
}
[class^="hljs-selector-pseudo"] {
    color: #E24B8A !important;
}
[class^="hljs-number"] {
    color: #dad9d8 !important;
}

[class^="Avatar-sc"] {
    background-color: darkgray !important;
    margin: 2px !important;
    padding: 2px !important;
    border-radius: 5px !important;
}


[class^="h3"]{
    margin: 2px !important;
    padding: 2px !important;
    border-radius: 5px !important;
    color: #cc1a58;
}

.h3 {
    text-align: left;

}

[class^="h3svg"]{
    margin: 2px !important;
    padding: 2px !important;
    border-radius: 5px !important;
    color: #19886D;
}
</style>
<body>` +
          document
            .querySelector('[class^="ThreadLayout__NodeWrapper"]')
            .innerHTML.replace(
              /<div class="Avatar__Wrapper-sc-1yo2jqv-3 hQqhqY">(.*?)<\/div>/g,
              '<h3 class="h3">You</h3>'
            )

            .replace(/<button[^>]*>.*?<\/button>/g, "")
            .replace(/<svg[^>]*>.*?<\/svg>/g, '<h3 class="h3svg">Bot</h3>') +
          "</body></html>",
      ],
      { type: "text/html" }
    )
  );

  const date = new Date();

  const dateString =
    date.getMonth() + 1 + "/" + date.getDate() + "/" + date.getFullYear();

  a.download = "chatGPT Save Chat -" + dateString + ".html";

  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(a.href);
})();

EOF
}
