# nu-modules

Nushell modules

## Development

While these are Nu modules, `main` is meant to be run as a command from the script. For example:

```bash
use notion.nu *; ./notion.nu users
```

## Notion

Notion's API is not like the others.

1. Notion requires a `Notion-Version` header. See [Versioning][1]
2. Notion requires you to create an "integration" that has the API key associated with it. [Create your first
   integration][2] to get the API key.
3. The user needs to connect the integration to a page. Navigate to a page in Notion and [connect your integration][3]
   to the page.
4. Since the integration is connected to a page or database, there is not a way to list all databases. The database ID
   needs to be provided as an argument to the Nu module.
5. The docs to [find the database ID][4] mention the workspace name but that does not seem to be the case.
6. The filters can be extremely sensitive. The error message is usually a very generic "invalid JSON". It's up to you to
   debug what filter is incorrect.

The docs mention this URL format.

```
https://www.notion.so/{workspace_name}/{database_id}?v={view_id}
```

The current URL format does not seem to include the `workspace_name`.

```
https://www.notion.so/{database_id}?v={view_id}
```

[1]: https://developers.notion.com/reference/versioning
[2]: https://developers.notion.com/docs/create-a-notion-integration
[3]: https://developers.notion.com/docs/create-a-notion-integration#give-your-integration-page-permissions
[4]: https://developers.notion.com/docs/working-with-databases#adding-pages-to-a-database

## Xero

Xero requires you to create an application which uses [OAuth 2.0][5] with a standard code or PKCE flow. Follow the
[Getting started guide][6] to create the application. The [Tools][7] section has [Postman][8] and [Insomnia][9] example
repos on GitHub that explain the authorization process in detail.

[5]: https://developer.xero.com/documentation/guides/oauth2/overview
[6]: https://developer.xero.com/documentation/getting-started-guide
[7]: https://developer.xero.com/documentation/sdks-and-tools/tools/overview
[8]: https://github.com/XeroAPI/Xero-Postman-Tutorial-PKCE-Edition
[9]: https://github.com/XeroAPI/Xero-Insomnia
