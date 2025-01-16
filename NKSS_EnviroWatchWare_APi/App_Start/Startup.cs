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
            //GlobalConfiguration.Configure(WebApiConfig.Register);
        }

        public void ConfigureAuth(IAppBuilder app)
        {
            // This is very important line Cross Origin Source (CORS) it is used to enable cross-site HTTP requests
            // For security reasons, browsers restrict cross-origin HTTP requests
            //app.UseCors(CorsOptions.AllowAll);
            var container = new UnityContainer();
            container.RegisterType<IUserRepository, UserRepository>(new HierarchicalLifetimeManager());
            container.RegisterType<IUserService, UserService>(new HierarchicalLifetimeManager());

            var oauthProvider = container.Resolve<OAuthProvider>();
            var OAuthOptions = new OAuthAuthorizationServerOptions
            {
                AllowInsecureHttp = true,
                TokenEndpointPath = new PathString("/auth/login"),
                AccessTokenExpireTimeSpan = TimeSpan.FromMinutes(30), // Token expiration time
                Provider = oauthProvider
            };

            app.UseOAuthBearerTokens(OAuthOptions);
            app.UseOAuthAuthorizationServer(OAuthOptions);
            app.UseOAuthBearerAuthentication(new OAuthBearerAuthenticationOptions());

            HttpConfiguration config = new HttpConfiguration();
            WebApiConfig.Register(config); // Register the request
        }
    }
}
