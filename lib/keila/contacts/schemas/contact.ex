defmodule Keila.Contacts.Contact do
  use Keila.Schema, prefix: "c"
  alias Keila.Contacts.Form

  @statuses Enum.with_index([
              :active,
              :unsubscribed,
              :unreachable
            ])

  schema "contacts" do
    field(:email, :string)
    field(:first_name, :string)
    field(:last_name, :string)
    field(:status, Ecto.Enum, values: @statuses, default: :active)
    field(:data, Keila.Repo.JsonField)
    belongs_to(:project, Keila.Projects.Project, type: Keila.Projects.Project.Id)
    timestamps()
  end

  @spec creation_changeset(t(), Ecto.Changeset.data(), Keila.Projects.Project.id()) ::
          Ecto.Changeset.t(t())
  def creation_changeset(struct \\ %__MODULE__{}, params, project_id) do
    struct
    |> cast(params, [:email, :first_name, :last_name, :project_id, :data])
    |> put_change(:project_id, project_id)
    |> validate_email()
    |> check_data_size_constraint()
  end

  @spec update_changeset(t(), Ecto.Changeset.data()) :: Ecto.Changeset.t(t())
  def update_changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:email, :first_name, :last_name, :data])
    |> validate_email()
    |> check_data_size_constraint()
  end

  @spec changeset_from_form(t(), Ecto.Changeset.data(), Form.t()) :: Ecto.Changeset.t(t())
  def changeset_from_form(struct \\ %__MODULE__{}, params, form) do
    cast_fields =
      form.field_settings
      |> Enum.filter(& &1.cast)
      |> Enum.map(&String.to_existing_atom(&1.field))

    required_fields =
      form.field_settings
      |> Enum.filter(&(&1.cast and &1.required))
      |> Enum.map(&String.to_existing_atom(&1.field))

    struct
    |> cast(params, cast_fields)
    |> validate_dynamic_required(required_fields)
    |> validate_email()
    |> put_change(:project_id, form.project_id)
  end

  defp validate_dynamic_required(changeset, required_fields)
  defp validate_dynamic_required(changeset, []), do: changeset
  defp validate_dynamic_required(changeset, fields), do: validate_required(changeset, fields)

  defp check_data_size_constraint(changeset) do
    changeset
    |> check_constraint(:data, name: :max_data_size, message: "max 8 KB data allowed")
  end

  @email_regex ~r/^[^\s@]+@[^\s@]+$/
  defp validate_email(changeset) do
    changeset
    |> validate_required([:email])
    |> update_change(:email, fn email ->
      if is_binary(email), do: String.trim(email)
    end)
    |> validate_format(:email, @email_regex, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 255)
    |> unique_constraint([:email, :project_id])
  end
end
