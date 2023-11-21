qa_help(){
 cat <<EOF

  Q and A on the command line.
  QA_ENGINE=openai
  OPENAI_API
EOF
}

qa_prompt(){

  cat <<EOF

  Create these functions and show documentation via qa_docs().
  qa_docs
  qa_status
  qa_set_apikey
  qa_set_engine (default to openai)
  qa_set_context (default to something simple and meaninful)
  q  interpret all command line tokens as as prompt string
  a  show answer from previous query
  as show list of answers

  Mainatin data in ~/.qa/
  
EOF
}
