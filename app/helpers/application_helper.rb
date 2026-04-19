module ApplicationHelper
  def form_label_classes
    "text-content-muted text-sm uppercase mb-2"
  end

  def form_input_classes(certificate)
    "block w-full px-3 py-2 shadow-sm rounded-md border border-black/30 dark:border-white/30 focus:outline-primary dark:focus:outline-primary-dark text-xl tracking-wide bg-background"
  end
end
