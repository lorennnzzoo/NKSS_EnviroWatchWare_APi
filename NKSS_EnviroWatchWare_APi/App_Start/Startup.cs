using Microsoft.Owin;
using Microsoft.Owin.Security.OAuth;
using Owin;
using System;
using NKSS_EnviroWatchWare_APi.Providers;
using System.Web.Http;
using Microsoft.AspNetCore.Cors.Infrastructure;
using Services;
using Services.Interfaces;
using Unity;
using Repositories.Interfaces;
using Repositories;
using Unity.Lifetime;

[assembly: OwinStartup(typeof(NKSS_EnviroWatchWare_APi.App_Start.Startup))]

namespace NKSS_EnviroWatchWare_APi.App_Start
{
    public class Startup
    {
        public void Configuration(IAppBuilder app)
        {
            ConfigureAuth(app);            
        }

        public void ConfigureAuth(IAppBuilder app)
        {            
            var container = new UnityContainer();
            container.RegisterType<IUserRepository, UserRepository>(new HierarchicalLifetimeManager());
            container.RegisterType<IUserService, UserService>(new HierarchicalLifetimeManager());
            container.RegisterType<ILicenseRepository, LicenseRepository>(new HierarchicalLifetimeManager());
            container.RegisterType<ILicenseService, LicenseService>(new HierarchicalLifetimeManager());
            container.RegisterType<ICryptoService, CryptoService>(new HierarchicalLifetimeManager());

            var oauthProvider = container.Resolve<OAuthProvider>();
            var OAuthOptions = new OAuthAuthorizationServerOptions
            {
                AllowInsecureHttp = true,
                TokenEndpointPath = new PathString("/Auth/Login"),
                AccessTokenExpireTimeSpan = TimeSpan.FromMinutes(30), 
                Provider = oauthProvider
            };

            app.UseOAuthBearerTokens(OAuthOptions);
            app.UseOAuthAuthorizationServer(OAuthOptions);
            app.UseOAuthBearerAuthentication(new OAuthBearerAuthenticationOptions());

            HttpConfiguration config = new HttpConfiguration();
            //WebApiConfig.Register(config);
        }
    }
}
