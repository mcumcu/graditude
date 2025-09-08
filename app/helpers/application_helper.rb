module ApplicationHelper
  def form_label_classes
    "text-gray-400 text-sm uppercase mb-2"
  end

  def form_input_classes(certificate)
    "block w-full px-3 py-2 shadow-sm rounded-md border border-gray-200 focus:outline-blue-600 focus:ring-blue-600 focus:border-blue-600 text-xl tracking-wide"
  end

  def form_select_classes
    "block w-full px-3 py-2 shadow-sm rounded-md border border-gray-200 focus:outline-blue-600 focus:ring-blue-600 focus:border-blue-600"
  end
end
