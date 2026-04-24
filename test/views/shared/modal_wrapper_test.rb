require "test_helper"

class SharedModalWrapperTest < ActionView::TestCase
  test "renders modal overlay, close button, and body content" do
    render inline: <<~ERB
      <%= render "shared/modal_wrapper", title: "Modal title" do %>
        Modal body content
      <% end %>
    ERB

    assert_select "div.fixed"
    assert_select "div.absolute"
    assert_select "button[onclick=\"history.back()\"]", text: "✖︎"
    assert_match "Modal body content", rendered
  end
end
