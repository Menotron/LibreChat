import { OpenIDIcon, SamlIcon } from '@librechat/client';

import SocialButton from './SocialButton';

import { useLocalize } from '~/hooks';

import { TStartupConfig } from 'librechat-data-provider';

function SocialLoginRender({
  startupConfig,
}: {
  startupConfig: TStartupConfig | null | undefined;
}) {
  const localize = useLocalize();

  if (!startupConfig) {
    return null;
  }

  const providerComponents: Record<string, React.ReactNode> = {
    openid: startupConfig.openidLoginEnabled && (
      <SocialButton
        key="openid"
        enabled={startupConfig.openidLoginEnabled}
        serverDomain={startupConfig.serverDomain}
        oauthPath="openid"
        Icon={() =>
          startupConfig.openidImageUrl ? (
            <img src={startupConfig.openidImageUrl} alt="OpenID Logo" className="h-5 w-5" />
          ) : (
            <OpenIDIcon />
          )
        }
        label={startupConfig.openidLabel}
        id="openid"
      />
    ),
    saml: startupConfig.samlLoginEnabled && (
      <SocialButton
        key="saml"
        enabled={startupConfig.samlLoginEnabled}
        serverDomain={startupConfig.serverDomain}
        oauthPath="saml"
        Icon={() =>
          startupConfig.samlImageUrl ? (
            <img src={startupConfig.samlImageUrl} alt="SAML Logo" className="h-5 w-5" />
          ) : (
            <SamlIcon />
          )
        }
        label={startupConfig.samlLabel ? startupConfig.samlLabel : localize('com_auth_saml_login')}
        id="saml"
      />
    ),
  };

  return (
    startupConfig.socialLoginEnabled && (
      <>
        {startupConfig.emailLoginEnabled && (
          <>
            <div className="relative mt-6 flex w-full items-center justify-center border border-t border-gray-300 uppercase dark:border-gray-600">
              <div className="absolute bg-white px-3 text-xs text-black dark:bg-gray-900 dark:text-white">
                Or
              </div>
            </div>
            <div className="mt-8" />
          </>
        )}
        <div className="mt-2">
          {startupConfig.socialLogins?.map((provider) => providerComponents[provider] || null)}
        </div>
      </>
    )
  );
}

export default SocialLoginRender;
