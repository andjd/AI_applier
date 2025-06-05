defmodule Questions do
  def answer(resume, questions) do
    system_prompt = File.read!("prompts/questions.txt")

    user_prompt = """
    Resume:
    #{resume}

    Questions:
    #{JSON.encode!(questions)}
    """

    options = %{system: system_prompt}

    case Helpers.LLM.ask(user_prompt, options) do
      {:ok, text} ->
        JSON.decode(text)
      {:error, reason} ->
        {:error, reason}
    end
  end
end
