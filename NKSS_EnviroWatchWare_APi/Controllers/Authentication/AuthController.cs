using Services;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Security.Claims;
using System.Web.Http;
using System.Web.Http.Cors;

namespace NKSS_EnviroWatchWare_APi.Controllers.Authentication
{
    [Authorize]
    [RoutePrefix("Auth")]
    public class AuthController : ApiController
    {
        private readonly UserService user_service;
        private readonly RoleService role_service;
        private readonly Helpers.Validator validator = new Helpers.Validator();
        public AuthController(UserService _user_service, RoleService _role_service)
        {
            this.user_service = _user_service;
            this.role_service = _role_service;
        }

        [HttpPost]        
        [Route("Register")]
        public IHttpActionResult Register(Models.Post.Authentication.User user)
        {
            try
            {
                var (isValid, errorMessage) = validator.ValidateProperties(user);
                if (!isValid)
                {
                    return BadRequest(errorMessage);
                }

                user_service.CreateUser(user);
                return Ok("Account Creation Successfull, Please Login");
            }
            catch (Exception ex)
            {
                HttpResponseMessage response = new HttpResponseMessage();
                if (ex.GetType() == typeof(Services.Exceptions.UserAlreadyExistsException))
                {
                    response = new HttpResponseMessage(HttpStatusCode.Conflict)
                    {
                        Content = new StringContent(ex.Message)
                    };
                }
                else if (ex.GetType() == typeof(Services.Exceptions.PhoneNumberTooLongException))
                {
                    response = new HttpResponseMessage(HttpStatusCode.RequestedRangeNotSatisfiable)
                    {
                        Content = new StringContent(ex.Message)
                    };
                }
                else
                {
                    response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                    {
                        Content = new StringContent(ex.Message)
                    };
                }
                return ResponseMessage(response);
            }
        }

        [HttpGet]
        [AllowAnonymous]
        [Route("GetRoles")]
        public IHttpActionResult GetRoles()
        {
            try
            {
                var roles = role_service.GetAllRoles();
                if (roles.Count() > 0)
                {
                    return Ok(roles);
                }
                return NotFound();
            }
            catch (Exception ex)
            {
                HttpResponseMessage response = new HttpResponseMessage();

                response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.Message)
                };

                return ResponseMessage(response);
            }
        }

        [HttpGet]
        [Route("GetUserRole")]
        public IHttpActionResult GetUserRole()
        {
            var claimsIdentity = User.Identity as ClaimsIdentity;
            if (claimsIdentity == null)
            {
                return Unauthorized();
            }
            var roleClaim = claimsIdentity.FindFirst(ClaimTypes.Role);

            if (roleClaim == null)
            {
                return NotFound();
            }
            return Ok(new { Role = roleClaim.Value });
        }

    }
}
