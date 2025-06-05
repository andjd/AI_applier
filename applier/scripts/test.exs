{_, _, qs} = JDInfoExtractor.extract_text_from_url("https://job-boards.greenhouse.io/calm/jobs/8022656002?gh_src=b4f5067c2us")

IO.inspect(qs)
