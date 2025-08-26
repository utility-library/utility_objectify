# **utility_objectify**
Take a raw entity and objectify it, make it manageable, programmable, and lifecycle-aware.

`utility_objectify` is a simple but powerful system that lets you add custom behavior to entities in FiveM. you can easily attach logic to them and manage their lifecycle (spawn, destroy, state changes, etc.).

Dependencies: 
- [utility_lib](https://github.com/utility-library/utility_lib)
- [leap](https://github.com/utility-library/leap)

> **Note:** `utility_objectify` is a work in progress and is still in development.

---

## 🚀 **Features**

- **Entity-to-Class Binding**: Bind any UtilityNet entity to a lua class and manage it with custom logic.
- **Lifecycle Hooks**: Run functions when entities are spawned, destroyed, or updated.
- **State Management**: Track and react to changes in an entity's state.
- **Plugins**: Bind additional classes to the entity for modular functionality.

## 📖 **Documentation**
[View the full documentation](https://utility-2.gitbook.io/utility-objectify/)

---

## 🛠 **How It Works**
### **The BaseEntity Class**

The `BaseEntity` class is the core class that manages the lifecycle of your entities and handles state changes. It's designed to be extended by other entity classes, providing basic functionality like OnSpawn, OnDestroy, and state change handling.

```lua
class MyEntity extends BaseEntity {
    OnSpawn = function()
        -- Do something when the entity is spawned
    end,

    OnDestroy = function()
        -- Do something when the entity is destroyed
    end
}
```

---

## 📝 **Installation**

1. Download the `utility_objectify` resource and place it in your server's `resources` folder.
2. In `server.cfg`, add the line to start the resource:
   ```bash
   start utility_objectify
   ```
3. In the manifest of your choosen resource, add the following line:
   ```lua
    client_script "@utility_objectify/build/client/api.lua
    server_script "@utility_objectify/build/server/api.lua
    ```

## 🔗 **Vendorizing**

1. Drag and drop your resource folder onto `vendorize.bat`.

This will create hardlinks to the `api.lua` files from `utility_objectify` inside your resource’s `client/` and `server/` folders.  
It allows your code to use `utility_objectify`'s functionality without needing the resource to be installed.

> **Note:** When distributing a resource that uses `utility_objectify` you need to provide attribution or credit the original project accordingly.

---

## 💡 **Why Use This?**

- **Simplifies Entity Management**: No more messy global variables, scattered functions, manual entity spawning and management.
- **Life Cycle Hooks**: Automatically handle logic when entities spawn, destroy, or update.
- **Modular**: Easily add new functionality with plugins making everything reusable.
- **State-Driven Logic**: Track and respond to changes in your entities states without loops or complex logic.

---

## ✨ **Contributing**

If you'd like to contribute, feel free to fork the repo, open issues, or submit pull requests. Contributions are always welcome!

---

## 📄 **License**

Apache License 2.0. See the [LICENSE](LICENSE) file for details.
