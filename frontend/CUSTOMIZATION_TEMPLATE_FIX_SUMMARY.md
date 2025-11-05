# Customization Template Fix - Summary

## Problem

The customization template feature was allowing users to add multiple nested customizations to a single template, which was confusing and incorrect. Users should only be able to define **ONE customization type per template**.

## Solution

Updated the customization template system to match the menu item customization structure, ensuring each template represents a single, reusable customization type.

## Changes Made

### 1. Model Changes (`lib/models/customization_template.dart`)

**Replaced `selectionType` with `type`:**
- Old: `selectionType` field with values 'single' or 'multiple'
- New: `type` field with values:
  - `'single_choice'` - Radio buttons (select one)
  - `'multiple_choice'` - Checkboxes (select multiple)
  - `'text_input'` - Free text input (notes/special instructions)
  - `'spice_level'` - Special spice level selector widget

**Added Type-Specific Fields:**
- `maxSelections` (int?) - For multiple_choice: limit number of selections
- `maxLength` (int?) - For text_input: character limit (default 200)
- `placeholder` (String?) - For text_input: placeholder text

**Added Helper Method:**
- `customizationTypeDisplayName` getter - Returns friendly type names:
  - "Single Choice (Radio)"
  - "Multiple Choice (Checkboxes)"
  - "Text Input (Notes)"
  - "Spice Level Selector"

**Updated Request Classes:**
- `CreateCustomizationTemplateRequest` - Now includes type and type-specific fields
- `UpdateCustomizationTemplateRequest` - Now supports updating type and type-specific fields

### 2. Form Screen Changes (`lib/screens/customization_template_form_screen.dart`)

**Updated State Fields:**
- Added: `_maxSelectionsController`, `_maxLengthController`, `_placeholderController`
- Changed: `_selectionType` → `_type`

**Updated UI:**
- **Type Dropdown** - Now shows all 4 customization types matching menu item form
- **Conditional Fields** - Shows type-specific inputs:
  - Multiple Choice: Max Selections field
  - Text Input: Max Length and Placeholder fields
- **Options Section** - Only displays for non-text types
- **Info Banner** - Updated to emphasize "ONE customization type per template"

**Validation:**
- Options now only required for non-text types
- Automatically clears options when switching to text_input type

### 3. List Screen Changes (`lib/screens/customization_template_list_screen.dart`)

**Updated Template Info Display:**
- Shows friendly type name using `customizationTypeDisplayName`
- For choice types: Shows option count (e.g., "Single Choice (Radio) • 4 options • Required")
- For text input: Shows max length if set (e.g., "Text Input (Notes) • Max 200 chars • Optional")

## Example Templates

### Template 1: "Spice Level"
- Type: Single Choice (Radio)
- Required: Yes
- Options:
  - "Mild" (+$0.00)
  - "Medium" (+$0.00)
  - "Hot" (+$0.50)
  - "Extra Hot" (+$1.00)

### Template 2: "Extra Toppings"
- Type: Multiple Choice (Checkboxes)
- Required: No
- Max Selections: 5
- Options:
  - "Extra Cheese" (+$2.00)
  - "Pepperoni" (+$1.50)
  - "Mushrooms" (+$1.00)
  - "Onions" (+$0.50)
  - "Olives" (+$0.75)

### Template 3: "Special Instructions"
- Type: Text Input (Notes)
- Required: No
- Max Length: 200
- Placeholder: "Any special requests?"
- Options: (none - text input doesn't need options)

### Template 4: "Preferred Spice Level"
- Type: Spice Level Selector
- Required: Yes
- Options: (predefined spice levels)

## Benefits

1. **Clarity** - One type per template makes it crystal clear what each template does
2. **Consistency** - Matches the menu item customization system exactly
3. **Reusability** - Templates can be imported directly into menu items
4. **Flexibility** - All 4 customization types supported with appropriate fields
5. **Validation** - Proper validation based on type (options required for choices, not for text)

## Backend Compatibility

The backend stores templates with `customization_config` as a JSON string. The new structure includes:

```json
{
  "type": "single_choice|multiple_choice|text_input|spice_level",
  "required": true|false,
  "options": [...], // only for non-text types
  "max_selections": 5, // optional, for multiple_choice
  "max_length": 200, // optional, for text_input
  "placeholder": "text" // optional, for text_input
}
```

This structure is compatible with the `CustomizationOption` model used in menu items.

## Files Modified

1. `/Users/josephsadaka/Repos/delivery_app/frontend/lib/models/customization_template.dart`
2. `/Users/josephsadaka/Repos/delivery_app/frontend/lib/screens/customization_template_form_screen.dart`
3. `/Users/josephsadaka/Repos/delivery_app/frontend/lib/screens/customization_template_list_screen.dart`

## Testing Checklist

- [ ] Create a Single Choice template (e.g., Size selector)
- [ ] Create a Multiple Choice template with max selections (e.g., Toppings)
- [ ] Create a Text Input template with placeholder (e.g., Special Instructions)
- [ ] Create a Spice Level template
- [ ] Edit an existing template and change its type
- [ ] Import template into a menu item
- [ ] Verify template displays correctly in list view
- [ ] Verify system-wide vs vendor-specific templates work correctly
- [ ] Test admin and vendor access controls

## Migration Notes

Existing templates with `selection_type: 'single'` or `selection_type: 'multiple'` will be automatically mapped to `type: 'single_choice'` or need manual update in the database if they should be other types.
