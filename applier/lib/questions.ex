defmodule Questions do
  def answer(resume, questions, application_id \\ nil) do
    system_prompt = File.read!("prompts/questions.txt")
    standard_questions = File.read!("assets/standard_questions.txt")

    user_prompt = """
    Resume:
    #{resume}

    Standard Questions & Answers:
    #{standard_questions}

    Questions:
    #{JSON.encode!(questions)}
    """

    options = %{system: system_prompt}

    case Helpers.LLM.ask(user_prompt, application_id, options) do
      {:ok, text} ->
        IO.inspect text
        Helpers.LLM.decode_json(text)
      {:error, reason} ->
        IO.inspect(reason)
        {:error, reason}
    end
  end

  def validate_responses(questions, responses) do
    IO.inspect(responses)
    bad_responses = questions
    |> Enum.map(&validate_single_response(&1, responses))
    |> Enum.filter(& &1 != nil)

    case bad_responses do
      [] -> :ok
      errors -> {:error, errors}
    end
  end

  defp validate_single_response(question, responses) do
    question_id = Map.get(question, :id)
    response= Map.get(responses, question_id)
    errors = []
    |> validate_required(question, response)
    |> validate_max_length(question, response)
    |> validate_options(question, response)

    case errors do
      [] -> nil
      _ ->
        %{
          question: question,
          response: response,
          errors: errors
        }
    end
  end

  defp validate_required(errors, question, response) do
    required = Map.get(question, :required, false)

    if required && (is_nil(response) || String.trim(to_string(Map.get(response, "response", ""))) == "") do
      ["This field is required" | errors]
    else
      errors
    end
  end

  defp validate_max_length(errors, question, response) do
    max_length = Map.get(question, :max_length)

    if max_length && response && String.length(to_string(Map.get(response, "response", ""))) > max_length do
      ["Response exceeds maximum length of #{max_length} characters" | errors]
    else
      errors
    end
  end

  defp validate_options(errors, question, response) do
    options = Map.get(question, "options", [])

    if length(options) > 0 && response && !Enum.member?(options, to_string(Map.get(response, "response", ""))) do
      ["Response must be one of: #{Enum.join(options, ", ")}" | errors]
    else
      errors
    end
  end

end
