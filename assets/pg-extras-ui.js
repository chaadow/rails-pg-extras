(function () {
  "use strict";

  function initCollapseToggles(root) {
    root.querySelectorAll("[data-pg-extras-collapse-toggle]").forEach(function (button) {
      if (button.dataset.pgExtrasBound === "true") return;
      button.dataset.pgExtrasBound = "true";

      button.addEventListener("click", function () {
        var parent = button.parentElement;
        if (!parent) return;

        var targets = parent.querySelectorAll("[data-pg-extras-collapse]");
        var expanded = button.getAttribute("aria-expanded") === "true";
        var nextExpanded = !expanded;

        targets.forEach(function (target) {
          target.classList.toggle("hidden", !nextExpanded);
        });

        button.setAttribute("aria-expanded", nextExpanded ? "true" : "false");
        button.textContent = nextExpanded
          ? button.dataset.expandedLabel
          : button.dataset.collapsedLabel;
      });

      button.setAttribute("aria-expanded", "false");
    });
  }

  function setCardExpanded(card, expanded) {
    var toggle = card.querySelector("[data-pg-extras-card-toggle]");
    var body = card.querySelector("[data-pg-extras-card-body]");
    var chevron = card.querySelector("[data-pg-extras-card-chevron]");
    if (!toggle || !body) return;

    toggle.setAttribute("aria-expanded", expanded ? "true" : "false");
    body.classList.toggle("hidden", !expanded);
    toggle.classList.toggle("border-b", expanded);
    if (chevron) {
      chevron.textContent = expanded ? "▾" : "▸";
    }
  }

  function initDiagnoseCards(root) {
    root.querySelectorAll("[data-pg-extras-card]").forEach(function (card) {
      var toggle = card.querySelector("[data-pg-extras-card-toggle]");
      if (!toggle || toggle.dataset.pgExtrasBound === "true") return;
      toggle.dataset.pgExtrasBound = "true";

      toggle.addEventListener("click", function () {
        var expanded = toggle.getAttribute("aria-expanded") === "true";
        setCardExpanded(card, !expanded);
      });
    });

    var expandAll = root.querySelector("[data-pg-extras-cards-expand-all]");
    var collapseAll = root.querySelector("[data-pg-extras-cards-collapse-all]");

    if (expandAll && expandAll.dataset.pgExtrasBound !== "true") {
      expandAll.dataset.pgExtrasBound = "true";
      expandAll.addEventListener("click", function () {
        root.querySelectorAll("[data-pg-extras-card]").forEach(function (card) {
          setCardExpanded(card, true);
        });
      });
    }

    if (collapseAll && collapseAll.dataset.pgExtrasBound !== "true") {
      collapseAll.dataset.pgExtrasBound = "true";
      collapseAll.addEventListener("click", function () {
        root.querySelectorAll("[data-pg-extras-card]").forEach(function (card) {
          setCardExpanded(card, false);
        });
      });
    }
  }

  function visibleOptions(list) {
    return Array.prototype.slice.call(
      list.querySelectorAll("[data-pg-extras-combobox-option]:not(.hidden)")
    );
  }

  function setActiveOption(options, index) {
    options.forEach(function (option, i) {
      option.classList.toggle("bg-blue-100", i === index);
    });

    if (index >= 0 && options[index]) {
      options[index].scrollIntoView({ block: "nearest" });
    }
  }

  function openList(combobox, list, input) {
    list.classList.remove("hidden");
    input.setAttribute("aria-expanded", "true");
    combobox.dataset.open = "true";
  }

  function closeList(combobox, list, input) {
    list.classList.add("hidden");
    input.setAttribute("aria-expanded", "false");
    combobox.dataset.open = "false";
  }

  function filterOptions(list, query) {
    var normalized = (query || "").trim().toLowerCase();

    list.querySelectorAll("[data-pg-extras-combobox-option]").forEach(function (option) {
      var label = (option.dataset.label || "").toLowerCase();
      var matches = !normalized || label.indexOf(normalized) !== -1;
      option.classList.toggle("hidden", !matches);
    });
  }

  function selectOption(form, input, valueInput, option) {
    if (!option || option.dataset.disabled === "true") return;

    var value = option.dataset.value || "";
    var label = option.dataset.label || value || "diagnose";

    input.value = label;
    valueInput.value = value;
    form.submit();
  }

  function initCombobox(combobox) {
    if (combobox.dataset.pgExtrasBound === "true") return;
    combobox.dataset.pgExtrasBound = "true";

    var form = combobox.closest("form");
    var input = combobox.querySelector("[data-pg-extras-combobox-input]");
    var list = combobox.querySelector("[data-pg-extras-combobox-list]");
    var valueInput = combobox.querySelector("[data-pg-extras-combobox-value]");
    var toggle = combobox.querySelector("[data-pg-extras-combobox-toggle]");
    var activeIndex = -1;

    if (!form || !input || !list || !valueInput) return;

    function refreshActive() {
      var options = visibleOptions(list);
      if (activeIndex >= options.length) activeIndex = options.length - 1;
      setActiveOption(options, activeIndex);
    }

    function moveActive(delta) {
      var options = visibleOptions(list);
      if (!options.length) return;

      if (activeIndex === -1) {
        activeIndex = delta > 0 ? 0 : options.length - 1;
      } else {
        activeIndex = (activeIndex + delta + options.length) % options.length;
      }

      // Skip disabled options when possible
      var guard = 0;
      while (options[activeIndex] && options[activeIndex].dataset.disabled === "true" && guard < options.length) {
        activeIndex = (activeIndex + delta + options.length) % options.length;
        guard += 1;
      }

      setActiveOption(options, activeIndex);
    }

    input.addEventListener("focus", function () {
      filterOptions(list, "");
      openList(combobox, list, input);
      refreshActive();
      input.select();
    });

    input.addEventListener("input", function () {
      filterOptions(list, input.value);
      openList(combobox, list, input);
      activeIndex = -1;
      refreshActive();
    });

    input.addEventListener("keydown", function (event) {
      if (event.key === "ArrowDown") {
        event.preventDefault();
        openList(combobox, list, input);
        moveActive(1);
      } else if (event.key === "ArrowUp") {
        event.preventDefault();
        openList(combobox, list, input);
        moveActive(-1);
      } else if (event.key === "Enter") {
        var options = visibleOptions(list);
        if (combobox.dataset.open === "true" && activeIndex >= 0 && options[activeIndex]) {
          event.preventDefault();
          selectOption(form, input, valueInput, options[activeIndex]);
        }
      } else if (event.key === "Escape") {
        closeList(combobox, list, input);
        activeIndex = -1;
      }
    });

    if (toggle) {
      toggle.addEventListener("click", function (event) {
        event.preventDefault();
        if (combobox.dataset.open === "true") {
          closeList(combobox, list, input);
        } else {
          filterOptions(list, "");
          openList(combobox, list, input);
          input.focus();
        }
      });
    }

    list.addEventListener("mousedown", function (event) {
      var option = event.target.closest("[data-pg-extras-combobox-option]");
      if (!option || option.dataset.disabled === "true") {
        event.preventDefault();
        return;
      }
      event.preventDefault();
      selectOption(form, input, valueInput, option);
    });

    document.addEventListener("click", function (event) {
      if (!combobox.contains(event.target)) {
        closeList(combobox, list, input);
        activeIndex = -1;
      }
    });
  }

  function initAll() {
    initCollapseToggles(document);
    initDiagnoseCards(document);
    document.querySelectorAll("[data-pg-extras-combobox]").forEach(initCombobox);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initAll);
  } else {
    initAll();
  }
})();
