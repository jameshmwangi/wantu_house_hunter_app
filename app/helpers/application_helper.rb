module ApplicationHelper
  def avatar_for(user, css_class: "wantu-avatar", img_class: "wantu-avatar__img")
    if user.avatar.attached?
      image_tag user.avatar, class: img_class, alt: user.full_name
    else
      user.full_name.first(1).upcase
    end
  end
end
