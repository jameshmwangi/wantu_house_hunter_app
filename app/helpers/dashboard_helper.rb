module DashboardHelper
  def nav_tab_class(active:)
    base = "nav-link border-0 border-bottom"
    active ? "#{base} active border-primary border-3 fw-bold text-dark" : "#{base} text-muted fw-bold"
  end

  def nav_tab_style(active:)
    'border-color: var(--primary-green) !important;' if active
  end
end
