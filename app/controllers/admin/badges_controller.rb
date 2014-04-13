class Admin::BadgesController < Admin::AdminController
  def index
    badges = Badge.all.to_a
    render_serialized(badges, BadgeSerializer, root: "badges")
  end

  def badge_types
    badge_types = BadgeType.all.to_a
    render_serialized(badge_types, BadgeTypeSerializer, root: "badge_types")
  end

  def create
    badge = Badge.new
    update_badge_from_params(badge)
    badge.save!
    render_serialized(badge, BadgeSerializer, root: "badge")
  end

  def update
    badge = find_badge
    update_badge_from_params(badge)
    badge.save!
    render_serialized(badge, BadgeSerializer, root: "badge")
  end

  def destroy
    find_badge.destroy
    render nothing: true
  end

  private
    def find_badge
      params.require(:id)
      Badge.find(params[:id])
    end

    def update_badge_from_params(badge)
      params.permit(:name, :description, :badge_type_id)
      badge.name = params[:name]
      badge.description = params[:description]
      badge.badge_type = BadgeType.find(params[:badge_type_id])
      badge
    end
end
