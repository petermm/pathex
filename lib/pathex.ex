defmodule Pathex do

  @moduledoc """
  This module contains macroses to be used by user

  Any macro here belongs to one of two categories:
  1) Macro which creates path closure (`sigil_P/2`, `path/2`, `~>/2`)
  2) Macro which uses path closure as path (`over/3`, `set/3`, `view/2`)

  Path closure is a closure which takes two arguments:
  1) `Atom.t()` with operaion name
  2) `Tuple.t()` of arguments of this operation
  """

  @type struct_type :: :map | :keyword | :list | :tuple
  @type key_type :: :integer | :atom | :binary

  @type path :: [{struct_type(), any()}]

  @type el_structure :: map() | list() | Keyword.t() | tuple()

  @type result :: {:ok, any()} | {:error, any()} | :error
  @type t :: (
    :get | :set | :update | :force_set,
    {el_structure()} | {el_structure(), any()} | {el_structure(), (any() -> any())}
  -> result())

  @type mod :: :map | :json | :naive

  @doc """
  Macro of three arguments which applies given function
  for item in the given path of given structure
  """
  defmacro over(path, struct, function) do
    quote generated: true do
      unquote(path).(:update, {unquote(struct), unquote(function)})
    end
  end

  @doc """
  Macro of three arguments which sets the given value
  in the given path of given structure
  """
  defmacro set(path, struct, value) do
    quote generated: true do
      unquote(path).(:set, {unquote(struct), unquote(value)})
    end
  end

  @doc """
  Macro of three arguments which sets the given value
  in the given path of given structure

  If the path does not exist it creates the path favouring maps
  when structure is unknown
  """
  defmacro force_set(path, struct, value) do
    quote generated: true do
      unquote(path).(:force_set, {unquote(struct), unquote(value)})
    end
  end

  @doc """
  Macro gets the value in the given path of the given structure
  """
  defmacro view(path, struct) do
    quote generated: true do
      unquote(path).(:get, {unquote(struct)})
    end
  end

  @doc """
  Sigil for paths. Has only two modes:
  `naive` (default) and `json`.
  Naive paths should look like `~P["string"/:atom/1]`
  Json paths should look like `~P[string/this_one_is_too/1/0]`
  """
  defmacro sigil_P({_, _, [string]}, mod) do
    mod = detect_mod(mod)
    string
    |> Pathex.Parser.parse(mod)
    #|> Pathex.Combination.from_suggested_path()
    |> Pathex.Builder.build(mod)
  end

  @doc """
  Creates path for given structure

  Example:
      iex> x = 1
      iex> mypath = path 1 / :atom / "string" / {"tuple?"} / x
  """
  defmacro path(quoted, mod \\ 'naive') do
    mod = detect_mod(mod)
    quoted
    |> Pathex.QuotedParser.parse(__CALLER__, mod)
    |> Pathex.Builder.build(mod)
  end

  @doc """
  Creates composition of two paths
  """
  defmacro a ~> b do
    quote generated: true do
      fn
        :get, arg ->
          with {:ok, res} <- unquote(a).(:get, arg) do
            unquote(b).(:get, {res})
          end

        :force_set, {struct, value} ->
          val =
            case unquote(a).(:get, {struct}) do
              :error       -> %{}
              {:ok, other} -> other
            end
          {:ok, val} = unquote(b).(:force_set, {val, value})
          unquote(a).(:force_set, {struct, val})

        cmd, {target, arg} ->
          with(
            {:ok, inner} <- unquote(a).(:get, {target}),
            {:ok, inner} <- unquote(b).(cmd, {inner, arg})
          ) do
            unquote(a).(:set, {target, inner})
          end
      end
    end
  end

  # Helper for detecring mod
  defp detect_mod(mod) when mod in ~w(naive map json)a, do: mod
  defp detect_mod(str) when is_binary(str), do: detect_mod('#{str}')
  defp detect_mod('json'), do: :json
  defp detect_mod('map'), do: :map
  defp detect_mod(_), do: :naive

end
