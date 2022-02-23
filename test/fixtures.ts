interface MaybeMetadata {
  name?: string;
  description?: string;
  image?: string;
  external_url?: string;
  attributes?: Array<{ trait_type: string; value: string }>;
}

export const metadataFromTokenURI = (tokenUri: string): MaybeMetadata => {
  const [prefix, encoded] = tokenUri.split(",");
  if (prefix !== "data:application/json;base64") {
    throw new Error("invalid token uri");
  }
  const json = Buffer.from(encoded, "base64").toString();
  const parsed = JSON.parse(json);
  return parsed;
};
