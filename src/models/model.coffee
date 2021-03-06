# Private helper function for serializing attributes recursively,
# Private helper function for serializing attributes recursively,
# creating objects which delegate to the original attributes
# in order to protect them from changes.
serializeAttributes = (model, attributes, modelStack) ->
	# Create a delegator object.
	delegator = Mildred.utils.beget attributes

	# Add model to stack.
	modelStack ?= {}
	modelStack[model.cid] = true

	# Map model/collection to their attributes. Create a property
	# on the delegator that shadows the original attribute.
	for key, value of attributes

		# Handle models.
		if value instanceof Backbone.Model
			delegator[key] = serializeModelAttributes value, model, modelStack

			# Handle collections.
		else if value instanceof Backbone.Collection
			serializedModels = []
			for otherModel in value.models
				serializedModels.push(
					serializeModelAttributes(otherModel, model, modelStack)
				)
			delegator[key] = serializedModels

	# Remove model from stack.
	delete modelStack[model.cid]

	# Return the delegator.
	delegator

# Serialize the attributes of a given model
# in the context of a given tree.
serializeModelAttributes = (model, currentModel, modelStack) ->
	# Nullify circular references.
	return null if model is currentModel or model.cid of modelStack
	# Serialize recursively.
	attributes = if typeof model.getAttributes is 'function'
		# Chaplin models.
		model.getAttributes()
	else
		# Backbone models.
		model.attributes
	serializeAttributes model, attributes, modelStack

class Mildred.Model extends Backbone.Model
  # This method is used to get the attributes for the view template
  # and might be overwritten by decorators which cannot create a
  # proper `attributes` getter due to ECMAScript 3 limits.
  getAttributes: ->
    @attributes

  # Return an object which delegates to the attributes
  # (i.e. an object which has the attributes as prototype)
  # so primitive values might be added and altered safely.
  # Map models to their attributes, recursively.
  serialize: ->
    serializeAttributes this, @getAttributes()

  # Disposal
  # --------

  disposed: false

  dispose: ->
    return if @disposed

    # Fire an event to notify associated collections and views.
    @trigger 'dispose', this

    # Unbind all referenced handlers.
    @stopListening()

    # Remove all event handlers on this module.
    @off()

    # Remove the collection reference, internal attribute hashes
    # and event handlers.
    properties = [
      'collection',
      'attributes', 'changed'
      '_escapedAttributes', '_previousAttributes',
      '_silent', '_pending',
      '_callbacks'
    ]
    delete this[prop] for prop in properties

    # Finished.
    @disposed = true