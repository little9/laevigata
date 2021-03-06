export class FieldManager {
    constructor(element, options) {
        this.element = $(element);

        this.options = options;

        this.options.label = this.getFieldLabel(this.element, options)

        this.addSelector = '.add'
        this.removeSelector = '.remove'

        this.adder    = this.createAddHtml(this.options)
        this.remover  = this.createRemoveHtml(this.options)

        this.controls = $(options.controlsHtml);

        this.inputTypeClass = options.inputTypeClass;
        this.fieldWrapperClass = options.fieldWrapperClass;
        this.warningClass = options.warningClass;
        this.listClass = options.listClass;

        this.init();
    }

    init() {
        this._addInitialClasses();
        this._addAriaLiveRegions()
        this._appendControls();
        this._attachEvents();
        this._addCallbacks();
    }

    _addInitialClasses() {
        this.element.addClass("managed");
        $(this.fieldWrapperClass, this.element).addClass("input-group input-append");
    }

    _addAriaLiveRegions() {
        $(this.element).find('.listing').attr('aria-live', 'polite')
    }

    // Add the "Add another" and "Remove" controls to the DOM
    _appendControls() {
        // We want to make these DOM additions idempotently, so exit if it's
        // already set up.
        if (!this._hasRemoveControl()) {
          this._createRemoveWrapper()
          this._createRemoveControl()
        }

        if (!this._hasAddControl()) {
          this._createAddControl()
        }
    }

    _createRemoveWrapper() {
      $(this.fieldWrapperClass, this.element).append(this.controls);
    }

    _createRemoveControl() {
      $(this.fieldWrapperClass + ' .field-controls', this.element).append(this.remover)
    }

    _createAddControl() {
      this.element.find(this.listClass).after(this.adder)
    }

    _hasRemoveControl() {
      return this.element.find(this.removeSelector).length > 0
    }

    _hasAddControl() {
      return this.element.find(this.addSelector).length > 0
    }

    _attachEvents() {
        this.element.on('click', this.removeSelector, (e) => this.removeFromList(e))
        this.element.on('click', this.addSelector, (e) => this.addToList(e))
    }

    _addCallbacks() {
        this.element.bind('managed_field:add', this.options.add);
        this.element.bind('managed_field:remove', this.options.remove);
    }

    _manageFocus() {
        $(this.element).find(this.listClass).children('li').last().find('.form-control').focus();
    }

    addToList( event ) {
        event.preventDefault();
        let $listing = $(event.target).closest(this.inputTypeClass).find(this.listClass)
        let $activeField = $listing.children('li').last()

        if (this.inputIsEmpty($activeField)) {
            this.displayEmptyWarning();
        } else {
            this.clearEmptyWarning();
            $listing.append(this._newField($activeField));
        }

        this._manageFocus()
    }

    inputIsEmpty($activeField) {
        return $activeField.children('input.multi-text-field').val() === '';
    }

    _newField ($activeField) {
        var $newField = this.createNewField($activeField);
        return $newField;
    }

    // If you're in the etd_research_field div AND there are fewer than 3 items selected, add a new entry field
    // OR
    // If you're in the keywords div, always make a new entry field
    createNewField($activeField) {
      var inResearchFields = !!$activeField.parents("div.etd_research_field").length
      var numberOfResearchFieldsLessThanThree = $('select#etd_research_field').length < 3
      var inKeywords = !!$activeField.parents("div.etd_keyword").length
      if ((inResearchFields && numberOfResearchFieldsLessThanThree) || inKeywords) {
        let $newField = $activeField.clone();
        let $newChildren = this.createNewChildren($newField);
        this.element.trigger("managed_field:add", $newChildren);

        if (!!$activeField.parents("div.etd_research_field").length && $('select#etd_research_field').length === 2) {
          $('.etd_research_field button.add').remove();
        }
        return $newField;
      }
    }

    clearEmptyWarning() {
        let $listing = $(this.listClass, this.element)
        $listing.children(this.warningClass).remove();
    }

    displayEmptyWarning() {
        let $listing = $(this.listClass, this.element)
        var $warningMessage  = $("<div class=\'message has-warning\'>cannot add another with empty field</div>");
        $listing.children(this.warningClass).remove();
        $listing.append($warningMessage);
    }

    removeFromList( event ) {
        event.preventDefault();
        var $field = $(event.target).parents(this.fieldWrapperClass).remove();
        this.element.trigger("managed_field:remove", $field);
        // max of 3 research fields allowed; if user removes one or two, must replace add link
        if ($('select#etd_research_field').length <=2) {
          this._createAddControl();
        }
        this._manageFocus();
    }

    destroy() {

        $(this.fieldWrapperClass, this.element).removeClass("input-append");
        this.element.removeClass("managed");
    }

    getFieldLabel($element, options) {
        var label = '';
        var $label = $element.find("label").first();

        if ($label.size && options.labelControls) {
          var label = $label.data('label') || $.trim($label.contents().filter(function() { return this.nodeType === 3; }).text());
          label = ' ' + label;
        }

        return label;
    }

    createAddHtml(options) {
        var $addHtml  = $(options.addHtml);
        $addHtml.find('.controls-add-text').html(options.addText + options.label);
        return $addHtml;
    }

    createRemoveHtml(options) {
        var $removeHtml = $(options.removeHtml);
        $removeHtml.find('.controls-remove-text').html(options.removeText);
        $removeHtml.find('.controls-field-name-text').html(options.label);
        return $removeHtml;
    }

    createNewChildren(clone) {
        let $newChildren = $(clone).children(this.inputTypeClass);
        $newChildren.val('').removeProp('required');
        $newChildren.first().focus();
        return $newChildren.first();
    }
}
