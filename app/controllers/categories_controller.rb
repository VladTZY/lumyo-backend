class CategoriesController < ApplicationController
  before_action :set_category, only: [ :show, :update, :destroy ]

  def index
    cats = current_user.categories.left_joins(:notes).group(:id).select(
      "categories.*, COUNT(note_categories.note_id) AS notes_count"
    )

    uncategorized_count = current_user.notes
      .left_joins(:note_categories)
      .where(note_categories: { id: nil })
      .count

    result = cats.map { |c| category_json(c) }
    result.unshift({ id: 0, title: "Uncategorized", notes_count: uncategorized_count, created_at: nil, updated_at: nil }) if uncategorized_count > 0

    render json: result
  end

  def show
    if params[:id] == "0"
      uncategorized_notes = current_user.notes
        .left_joins(:note_categories)
        .where(note_categories: { id: nil })
      return render json: { id: 0, title: "Uncategorized", notes: uncategorized_notes }
    end

    render json: @category, include: :notes
  end

  def create
    category = current_user.categories.build(category_params)
    if category.save
      render json: category, status: :created
    else
      render json: { errors: category.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @category.update(category_params)
      render json: @category
    else
      render json: { errors: @category.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @category.destroy
    head :no_content
  end

  private

  def set_category
    return if params[:id] == "0"
    @category = current_user.categories.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Category not found" }, status: :not_found
  end

  def category_params
    params.require(:category).permit(:title)
  end

  def category_json(cat)
    {
      id: cat.id,
      title: cat.title,
      notes_count: cat.try(:notes_count) || 0,
      created_at: cat.created_at,
      updated_at: cat.updated_at
    }
  end
end
