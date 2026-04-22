# GraditudeFactory

A flexible, template-based certificate PDF generation gem for Ruby on Rails. Create beautiful certificates with custom templates, support for multiple schools, and automatic PNG rendering.

## Features

- **Template-Based Architecture**: Define custom certificate templates with a simple DSL
- **Multi-School Support**: Bundled templates for Penn and Westtown schools; easily add more
- **Asset Management**: Bundle fonts and images with your templates; override at runtime if needed
- **PNG Rendering**: Automatically convert PDFs to high-quality PNG images
- **Rails Integration**: Mixin concern for seamless controller integration
- **Configurable Assets**: Use bundled defaults or provide custom asset paths

## Installation

### 1. Add to Gemfile

```ruby
gem "graditude_factory", path: "../graditude_factory"
# or for remote gem
gem "graditude_factory", git: "https://github.com/yourusername/graditude_factory.git"
```

### 2. Bundle Install

```bash
bundle install
```

### 3. Create Initializer (Optional)

Create `config/initializers/graditude_factory.rb`:

```ruby
GraditudeFactory.configure do |config|
  # Use bundled assets by default, or override:
  # config.font_dir = Rails.root.join("app", "assets", "fonts")
  # config.image_dir = Rails.root.join("app", "assets", "images")
end
```

## Usage

### Using Pre-Built Templates

#### Option 1: Include in Controller

```ruby
class CertificatesController < ApplicationController
  include GraditudeFactory::Concerns::Printable
  
  def create
    params = {
      graduate_name: "Jane Smith",
      degree: "Bachelor of Arts",
      major: "Computer Science",
      honoree_name: "Mom and Dad",
      presented_on: "May 15, 2026",
      message: "Thanks for all your support"
    }
    
    # Generate Penn certificate PDF
    pdf = generate_certificate_pdf(GraditudeFactory::Certificates::PennTemplate, params)
    pdf.render_file("certificate.pdf")
    
    # Or generate Westtown certificate
    pdf = generate_certificate_pdf(GraditudeFactory::Certificates::WesttownTemplate, params)
    pdf.render_file("certificate.pdf")
  end
end
```

#### Option 2: Direct Template Usage

```ruby
template = GraditudeFactory::Certificates::PennTemplate.new({
  graduate_name: "John Doe",
  degree: "Master of Science",
  major: "Engineering",
  honoree_name: "Penn Engineering",
  presented_on: "June 1, 2026"
})

pdf = template.generate
pdf.render_file("my_certificate.pdf")
```

### Converting PDF to PNG

```ruby
class CertificatesController < ApplicationController
  include GraditudeFactory::Concerns::Printable
  
  def preview
    pdf = generate_certificate_pdf(GraditudeFactory::Certificates::WesttownTemplate, params)
    pdf_path = temp_pdf_path(@certificate.id).to_s
    pdf.render_file(pdf_path)
    
    png_path = temp_png_path(@certificate.id).to_s
    render_certificate_png(pdf_path, png_path)
    
    # Use png_path for preview
  end
end
```

## Creating a Custom School Template

### 1. Create Template Class

Create `lib/my_app/certificates/custom_school_template.rb`:

```ruby
module MyApp
  module Certificates
    class CustomSchoolTemplate < GraditudeFactory::Certificates::Template
      # Define page layout
      def page_config
        {
          page_size: [200.mm, 250.mm],  # Custom dimensions
          page_layout: :landscape,
          margin: [0, 0, 0, 0]
        }
      end

      # Main document font
      def document_font
        asset_path(:font, "YourFont.ttf")
      end

      # Additional fonts for different sections
      def heading_font
        asset_path(:font, "YourHeadingFont.ttf")
      end

      def signature_font
        asset_path(:font, "HomemadeApple-Regular.ttf")
      end

      # Define which assets are used
      def template_assets
        {
          background: asset_path(:image, "school_background.jpg"),
          banner: asset_path(:image, "school_logo.svg"),
          seal: asset_path(:image, "school_seal.png")
        }
      end

      # Render page layout and header
      def render_header(pdf)
        background = template_assets[:background]
        banner_path = template_assets[:banner]
        seal_path = template_assets[:seal]

        # Background
        pdf.float do
          pdf.image background, width: pdf.margin_box.width, height: pdf.margin_box.height, position: :center
        end

        pdf.move_down(25.mm)

        # Logo/Banner
        pdf.svg File.read(banner_path), width: 200.mm, position: :center

        pdf.move_down(15.mm)

        # Seal/Emblem
        pdf.image seal_path, width: 35.mm, position: :center

        pdf.move_down(8.mm)

        # Header text
        pdf.text "Certificate of Achievement", align: :center, size: 6.mm

        pdf.move_down(10.mm)
      end

      # Render main certificate content
      def render_content(pdf)
        graduate_name = @params["graduate_name"] || " "
        degree = @params["degree"]
        honoree_name = @params["honoree_name"] || " "
        major = @params["major"]
        nouns = @params["nouns"]&.reject { |n| n.empty? } || []
        message = @params["message"] || ""
        presented_on = @params["presented_on"]

        # Graduate name (large)
        pdf.font(heading_font) do
          pdf.text graduate_name.to_s, align: :center, size: 9.mm
        end

        pdf.move_down(5.mm)

        # Achievement text
        text_parts = [
          "has successfully completed",
          degree || "their program",
          nouns.any? ? "in #{nouns.join(' and ')}" : nil
        ].compact.join(" ")
        
        pdf.text text_parts, align: :center, size: 5.mm

        pdf.move_down(5.mm)

        # School/Organization name
        pdf.font(heading_font) do
          pdf.text honoree_name.to_s, align: :center, size: 8.mm
        end

        pdf.move_down(8.mm)

        # Date
        pdf.text "Awarded #{presented_on}", align: :center, size: 4.mm

        pdf.move_down(10.mm)

        # Signature area
        pdf.font(signature_font) do
          pdf.text graduate_name.to_s, align: :center, size: 5.mm
        end

        pdf.text major.to_s, align: :center, size: 3.mm if major

        # Message/honors
        if message.present?
          pdf.move_down(5.mm)
          pdf.text message, align: :center, size: 4.mm, style: :italic
        end
      end
    end
  end
end
```

### 2. Add Fonts and Images

#### Create Asset Directory Structure

```
app/assets/
├── fonts/
│   ├── YourFont.ttf
│   ├── YourHeadingFont.ttf
│   └── HomemadeApple-Regular.ttf
└── images/
    ├── school_background.jpg
    ├── school_logo.svg
    └── school_seal.png
```

#### Option A: Vendor Inside Gem (Recommended for Distribution)

If creating a separate `school_name_template` gem:

```
lib/
├── school_name_template/
│   ├── assets/
│   │   ├── fonts/
│   │   │   ├── YourFont.ttf
│   │   │   └── YourHeadingFont.ttf
│   │   └── images/
│   │       ├── school_background.jpg
│   │       ├── school_logo.svg
│   │       └── school_seal.png
│   └── certificates/
│       └── custom_school_template.rb
├── school_name_template.rb
└── version.rb
```

#### Option B: Override Asset Paths (For App-Specific Templates)

```ruby
# In your controller or initializer
GraditudeFactory.configure do |config|
  config.font_dir = Rails.root.join("app", "assets", "fonts")
  config.image_dir = Rails.root.join("app", "assets", "images")
end
```

### 3. Use Your Template

```ruby
class CertificatesController < ApplicationController
  include GraditudeFactory::Concerns::Printable
  
  def create
    params = {
      graduate_name: "Alice Johnson",
      degree: "Professional Certificate",
      major: "Advanced Studies",
      honoree_name: "Custom School",
      presented_on: "July 1, 2026",
      message: "With Honor"
    }
    
    pdf = generate_certificate_pdf(MyApp::Certificates::CustomSchoolTemplate, params)
    pdf.render_file("certificate.pdf")
  end
end
```

## Parameter Reference

### Standard Parameters

All templates accept the following parameters in the hash:

| Parameter | Type | Description | Required |
|-----------|------|-------------|----------|
| `graduate_name` | String | Name of the graduate | Yes |
| `degree` | String | Degree or certification name | No |
| `major` | String | Major or specialization | No |
| `nouns` | Array | Honors or distinctions (e.g., ["Distinction", "Honors"]) | No |
| `honoree_name` | String | School or organization name | Yes |
| `message` | String | Additional message or honors | No |
| `presented_on` | String | Date presented (e.g., "May 15, 2026") | Yes |
| `signature_path` | String | Path to signature image | No |

### Example

```ruby
params = {
  graduate_name: "Sarah Williams",
  degree: "Bachelor of Science",
  major: "Biology",
  nouns: ["Summa Cum Laude", "Dean's List"],
  honoree_name: "University of Pennsylvania",
  presented_on: "May 20, 2026",
  message: "Graduated with Distinction"
}
```

## Template Architecture

### Template Lifecycle

1. **Initialization**: Template created with parameters
2. **Document Creation**: Base document created with page config
3. **Header Rendering**: Background, logos, and initial styling
4. **Content Rendering**: Main certificate text and layout
5. **PDF Generation**: Final PDF document returned

### Helper Methods

Templates inherit these utility methods:

- `width` - Get full page width
- `half_width` - Get half page width
- `margin_horizontal` - Standard horizontal margin (30mm default)
- `signature_width` - Standard signature area width (70mm default)
- `asset_path(type, filename)` - Resolve font or image paths
- `create_document` - Initialize Prawn document
- `generate` - Generate complete PDF

### Accessing Prawn PDF Methods

```ruby
def render_content(pdf)
  # Standard Prawn PDF methods are available
  pdf.text "Hello", align: :center, size: 12.pt
  pdf.image "path/to/image.png", width: 100.mm
  pdf.move_down(10.mm)
  pdf.svg File.read("path/to/file.svg"), width: 150.mm
  
  # Access current position and bounds
  current_y = pdf.cursor
  page_width = pdf.bounds.width
  page_height = pdf.bounds.height
end
```

## Built-In Templates

### PennTemplate

Penn/University of Pennsylvania certificate design with:
- Letter size, landscape
- Engraver font for main text
- Penn logo and seal
- Clean, traditional layout

**Parameters**: All standard parameters supported

### WesttownTemplate

Westtown School certificate design with:
- Custom dimensions (175mm × 227mm)
- Jost and Literata fonts
- Westtown logo and seal
- Borders and formal layout

**Parameters**: All standard parameters supported

## Best Practices

### Asset Management

1. **Fonts**: Use TTF or OTF formats; embed in gem or app
2. **Images**: Use SVG for logos (scalable), JPG/PNG for backgrounds
3. **Storage**: Keep assets with template code for portability
4. **Accessibility**: Test fonts render correctly on different systems

### Template Design

1. **Responsive Layout**: Use `mm` units for consistency
2. **Font Fallbacks**: Test with multiple fonts
3. **Testing**: Generate actual PDFs during development
4. **Documentation**: Comment non-obvious layout decisions
5. **Reusability**: Extract common styling to helper methods

### Controller Integration

```ruby
class CertificatesController < ApplicationController
  include GraditudeFactory::Concerns::Printable
  
  def generate
    pdf = generate_certificate_pdf(
      template_class,
      certificate_params
    )
    
    # Save or stream
    pdf.render_file(temp_pdf_path(@certificate.id).to_s)
    
    # Cache or serve
    send_file("certificate.pdf", type: "application/pdf")
  end
  
  private
  
  def template_class
    case @certificate.school
    when "penn"
      GraditudeFactory::Certificates::PennTemplate
    when "westtown"
      GraditudeFactory::Certificates::WesttownTemplate
    when "custom"
      MyApp::Certificates::CustomSchoolTemplate
    end
  end
  
  def certificate_params
    @certificate.data.merge(presented_on: Date.today.to_s)
  end
end
```

## Troubleshooting

### Fonts Not Found

**Problem**: `Prawn::Errors::UnknownFont`

**Solution**:
1. Verify font file exists: `File.exist?(font_path)`
2. Check `GraditudeFactory.font_dir` configuration
3. Ensure path is absolute, not relative

```ruby
def document_font
  font_path = asset_path(:font, "MyFont.ttf")
  puts "Font path: #{font_path}"
  puts "Font exists: #{File.exist?(font_path)}"
  font_path
end
```

### Images Not Rendering

**Problem**: Images don't appear in PDF

**Solution**:
1. Verify image file exists and is readable
2. Use absolute paths, not relative
3. Check SVG validation for SVG files

```ruby
def template_assets
  {
    banner: asset_path(:image, "logo.svg").tap { |p| puts "Banner: #{p}, exists: #{File.exist?(p)}" }
  }
end
```

### PDF Generation Slow

**Problem**: PDF takes too long to generate

**Solution**:
1. Cache static elements (backgrounds, logos)
2. Use SVG for scalable graphics instead of raster
3. Minimize file operations; read files once per request

### PNG Rendering Issues

**Problem**: PNG conversion fails

**Solution**:
1. Verify `pdftoimage` gem is installed
2. Ensure PDF was generated successfully first
3. Check temp directory permissions

```ruby
def render_certificate_png(pdf_path, png_path)
  FileUtils.mkdir_p(File.dirname(png_path))
  
  page = PDFToImage.open(pdf_path).first
  if page
    page.resize("1024").save(png_path)
  else
    raise "Failed to open PDF: #{pdf_path}"
  end
  
  png_path
end
```

## API Reference

### GraditudeFactory Module

```ruby
GraditudeFactory.configure { |config| ... }
GraditudeFactory.font_dir              # Get/set font directory
GraditudeFactory.image_dir             # Get/set image directory
```

### Template Base Class

```ruby
template = MyTemplate.new(params)
template.generate                      # Returns Prawn::Document
template.params                        # Access parameters
template.font_dir                      # Asset font directory
template.image_dir                     # Asset image directory
```

### Printable Concern

```ruby
include GraditudeFactory::Concerns::Printable

generate_certificate_pdf(template_class, params)  # Returns PDF
render_certificate_png(pdf_path, png_path)        # Convert PDF to PNG
default_certificate_params                        # Get default params hash
temp_pdf_path(filename)                           # Get temp PDF file path
temp_png_path(filename)                           # Get temp PNG file path
```

## Contributing

To add new templates or improve the gem:

1. Create template in `lib/graditude_factory/certificates/`
2. Add specs in `spec/graditude_factory/certificates/`
3. Bundle required assets
4. Update documentation
5. Submit pull request

## License

MIT License - See LICENSE file for details

## Support

For issues, questions, or template contributions:
- Check existing documentation and examples
- Review bundled templates for patterns
- Test with actual Prawn output
- Verify asset paths and permissions
