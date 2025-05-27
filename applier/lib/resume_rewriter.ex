defmodule ResumeRewriter do
  @moduledoc """
  Module for parsing YAML resume data and applying it to LaTeX templates.
  """

  def parse_yaml_and_generate_latex(yaml_string, template_path) do
    with {:ok, parsed_data} <- parse_yaml(yaml_string),
         {:ok, latex_output} <- generate_latex(parsed_data, template_path) do
      {:ok, latex_output}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp parse_yaml(yaml_string) do
      IO.puts(yaml_string)
      parsed = YamlElixir.read_from_string!(yaml_string)
      IO.inspect(parsed)
      {:ok, parsed}
  end

  defp generate_latex(resume_data, template) do
  IO.inspect(resume_data)
    try do
      # Convert the template to an EEx template and evaluate it
      latex_output = EEx.eval_file(template, assigns: [
        summary: resume_data["summary"],
        skills: resume_data["skills"],
        experience: resume_data["experience"]
      ])
      {:ok, latex_output}
    rescue
      e -> {:error, "Template processing failed: #{inspect(e)}"}
    end
  end
end
