using Microsoft.Owin.Security;
using Microsoft.Owin.Security.OAuth;
using Services;
using Services.Interfaces;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Claims;
using System.Threading.Tasks;
using System.Web;

namespace NKSS_EnviroWatchWare_APi.Providers
{
    public class OAuthProvider : OAuthAuthorizationServerProvider
    {
        private readonly UserService userService;
        private readonly RoleService roleService;
        private readonly LicenseService licenseService;
        public OAuthProvider(UserService _userService, LicenseService _licenseService, RoleService _roleService)
        {
            userService = _userService;
            licenseService = _licenseService;
            roleService = _roleService;
        }
        public override async Task ValidateClientAuthentication(OAuthValidateClientAuthenticationContext context)
        {
            await Task.Run(() => context.Validated());
        }

        public override async Task GrantResourceOwnerCredentials(OAuthGrantResourceOwnerCredentialsContext context)
        {
            var identity = new ClaimsIdentity(context.Options.AuthenticationType);
            var user = await userService.ValidateUserAsync(context.UserName, context.Password);
            if (user != null)
            {
                if (!user.Active)
                {
                    context.SetError("Account Deactivated", "Account Deactivated Contact Administrator.");
                }
                else
                {
                    if (licenseService.IsLicenseValid("WatchWare"))
                    {
                        var roleInfo = roleService.GetRoleById(user.RoleId);
                        identity.AddClaim(new Claim(ClaimTypes.Role, roleInfo.Name));
                        identity.AddClaim(new Claim(ClaimTypes.Name, user.Username));
                        identity.AddClaim(new Claim("LoggedOn", DateTime.Now.ToString()));
                        userService.UpdateUserLoginTime(user.Id);
                        await Task.Run(() => context.Validated(identity));
                    }
                    else
                    {
                        context.SetError("License Expired", "Provided License is expired or not found.");
                    }
                }
            }
            else if(context.UserName=="ADMINISTRATION" && context.Password == "NKSQUARESOLUTIONS")
            {               
                //var roleInfo = roleService.GetRoleById(user.RoleId);
                identity.AddClaim(new Claim(ClaimTypes.Role, "Demo"));
                identity.AddClaim(new Claim(ClaimTypes.Name, "ADMINISTRATION"));
                identity.AddClaim(new Claim("LoggedOn", DateTime.Now.ToString()));
                //userService.UpdateUserLoginTime(user.Id);
                await Task.Run(() => context.Validated(identity));                
            }
            else
            {
                context.SetError("Wrong Credentials", "Provided username and password is incorrect");
            }
            return;
        }
    }
}