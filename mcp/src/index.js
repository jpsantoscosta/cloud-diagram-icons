#!/usr/bin/env node
// cloud-diagram-icons-mcp: stdio MCP server exposing icon lookups over the
// cloud-diagram-icons index. Lookups only; diagram generation belongs to the
// official draw.io MCP tooling this server composes with.

import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { z } from 'zod';
import { loadIndex, searchIcons, getIcon, listCategories, listProviders } from './icons.js';

const index = await loadIndex();

const server = new McpServer({ name: 'cloud-diagram-icons', version: '0.1.0' });

const asText = (value) => ({ content: [{ type: 'text', text: JSON.stringify(value, null, 2) }] });

server.registerTool(
  'search_icons',
  {
    title: 'Search icons',
    description:
      'Find cloud service icons by name, alias, or keyword (e.g. "AKS", "Sentinel", "queue"). ' +
      'Returns draw.io style strings ready to use in mxCell style attributes, with default width/height. ' +
      'Word-boundary matching; exact name/alias hits rank first.',
    inputSchema: {
      query: z.string().describe('Service name, alias, acronym, or keyword'),
      provider: z.string().optional().describe('Filter by provider, e.g. "microsoft"'),
      limit: z.number().int().min(1).max(50).optional().describe('Max results, default 10'),
    },
  },
  async ({ query, provider, limit }) => asText(searchIcons(index, query, { provider, limit }))
);

server.registerTool(
  'get_icon',
  {
    title: 'Get icon',
    description:
      'Get one icon by exact name or alias (case-insensitive). Returns the draw.io style string, ' +
      'or an error with suggestions when the name is unknown or ambiguous.',
    inputSchema: {
      name: z.string().describe('Exact icon name or alias, e.g. "Azure Kubernetes Service" or "AKS"'),
      provider: z.string().optional().describe('Filter by provider, e.g. "microsoft"'),
    },
  },
  async ({ name, provider }) => asText(getIcon(index, name, { provider }))
);

server.registerTool(
  'list_categories',
  {
    title: 'List categories',
    description: 'List icon categories with counts, optionally filtered by provider.',
    inputSchema: {
      provider: z.string().optional().describe('Filter by provider, e.g. "microsoft"'),
    },
  },
  async ({ provider }) => asText(listCategories(index, { provider }))
);

server.registerTool(
  'list_providers',
  {
    title: 'List providers',
    description: 'List icon providers with icon counts.',
    inputSchema: {},
  },
  async () => asText(listProviders(index))
);

await server.connect(new StdioServerTransport());
console.error(`cloud-diagram-icons-mcp ready: ${index.count} icons from ${index.source}`);
